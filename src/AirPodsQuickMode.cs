using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using System.Speech.Synthesis;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;

[assembly: System.Reflection.AssemblyVersion("0.1.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("0.1.0.0")]

[DataContract] sealed class Settings {
    [DataMember] public string Microphone = "";
    [DataMember] public int ToggleKey = (int)Keys.F9;
    [DataMember] public int StatusKey = (int)Keys.F10;
    [DataMember] public int OffKey = (int)Keys.F11;
    [DataMember] public uint Modifiers = 3;
    [DataMember] public bool SpokenFeedback = true;
    [DataMember] public string Language = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "tr" ? "tr" : "en";
    public void Validate() {
        if (ToggleKey < (int)Keys.F1 || ToggleKey > (int)Keys.F24 || StatusKey < (int)Keys.F1 || StatusKey > (int)Keys.F24 || OffKey < (int)Keys.F1 || OffKey > (int)Keys.F24)
            throw new Exception("Shortcut keys must be F1-F24.");
        if (ToggleKey == StatusKey || ToggleKey == OffKey || StatusKey == OffKey) throw new Exception("Shortcut keys must be different.");
        if (Modifiers != 3 && Modifiers != 6 && Modifiers != 5 && Modifiers != 7) throw new Exception("Invalid shortcut modifiers.");
        if (Language != "tr" && Language != "en") throw new Exception("Invalid language.");
        if (Microphone == null) Microphone = "";
    }
    public string Shortcut(int key) {
        return ((Modifiers & 2) != 0 ? "Ctrl+" : "") + ((Modifiers & 1) != 0 ? "Alt+" : "") + ((Modifiers & 4) != 0 ? "Shift+" : "") + (Keys)key;
    }
    public static Settings Load() {
        if (!File.Exists(Program.ConfigPath)) return new Settings();
        using (Stream s = File.OpenRead(Program.ConfigPath)) {
            Settings result = (Settings)new DataContractJsonSerializer(typeof(Settings)).ReadObject(s);
            result.Validate(); return result;
        }
    }
    public void Save() {
        Validate();
        string temp = Program.ConfigPath + ".tmp";
        using (Stream s = File.Create(temp)) new DataContractJsonSerializer(typeof(Settings)).WriteObject(s, this);
        if (File.Exists(Program.ConfigPath)) File.Replace(temp, Program.ConfigPath, null);
        else File.Move(temp, Program.ConfigPath);
    }
}

static class Program {
    public static readonly string DataPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AirPodsQuickMode", "data");
    public static readonly string LogPath = Path.Combine(DataPath, "status.log");
    public static readonly string ConfigPath = Path.Combine(DataPath, "settings.json");
    public static Settings Config;
    public static string T(string tr, string en) { return Config != null && Config.Language == "tr" ? tr : en; }
    public static void Log(string s) { try {
        Directory.CreateDirectory(DataPath);
        if (File.Exists(LogPath) && new FileInfo(LogPath).Length > 1048576) File.Move(LogPath, LogPath + "." + DateTime.UtcNow.Ticks + ".old");
        foreach(string old in Directory.GetFiles(DataPath,"status.log.*.old")) File.Delete(old);
        File.AppendAllText(LogPath, DateTime.Now.ToString("s") + " " + s + Environment.NewLine);
    } catch { } }
    [STAThread] static int Main(string[] args) {
        try {
            Directory.CreateDirectory(DataPath);
            if (args.Length > 0 && args[0] == "--self-test") { SelfTest(); return 0; }
            Config = Settings.Load();
            if (args.Length > 0 && args[0] == "--devices") {
                File.WriteAllLines(Path.Combine(DataPath, "devices.txt"), Capture.DeviceNames());
                return 0;
            }
            if (args.Length > 0 && args[0] == "--test") {
                using (Capture c = new Capture()) {
                    c.Open(Config.Microphone);
                    for (int i = 0; i < 60; i++) { Thread.Sleep(50); c.Pump(); }
                    Log("TEST PASS: capture opened, buffers received=" + c.Received);
                    if (c.Received == 0) throw new Exception("No microphone buffers received");
                }
                Log("TEST PASS: capture released"); return 0;
            }
            using (Mutex m = new Mutex(false, "Local\\AirPodsQuickMode")) {
                bool owned;
                try { owned = m.WaitOne(0); } catch (AbandonedMutexException) { owned = true; }
                if (!owned) {
                    if (args.Length > 0 && args[0] == "--settings") using (EventWaitHandle e = EventWaitHandle.OpenExisting("Local\\AirPodsQuickMode.Settings")) e.Set();
                    return 0;
                }
                try { Application.EnableVisualStyles(); Application.Run(new ModeContext(args.Length > 0 && args[0] == "--settings")); } finally { m.ReleaseMutex(); }
            }
            return 0;
        } catch (Exception e) { Log("ERROR " + e); if(args.Length == 0 || args[0] == "--settings") MessageBox.Show(e.Message + "\n\n" + LogPath, "AirPods Quick Mode", MessageBoxButtons.OK, MessageBoxIcon.Error); return 1; }
    }
    static void SelfTest() {
        Settings c = new Settings(); c.Validate();
        bool rejected = false; c.OffKey = c.ToggleKey;
        try { c.Validate(); } catch { rejected = true; }
        if(!rejected) throw new Exception("Duplicate hotkey accepted");
        c = new Settings { Microphone = "AirPods Türkçe test", Language = "tr", Modifiers = 6 };
        using(MemoryStream ms = new MemoryStream()) {
            DataContractJsonSerializer json = new DataContractJsonSerializer(typeof(Settings));
            json.WriteObject(ms,c); ms.Position=0;
            Settings read = (Settings)json.ReadObject(ms); read.Validate();
            if(read.Microphone != c.Microphone || read.Shortcut(read.ToggleKey) != "Ctrl+Shift+F9") throw new Exception("Settings roundtrip failed");
        }
        Log("SELF TEST PASS: duplicate shortcuts rejected; Unicode settings roundtrip; shortcut formatting");
    }
}

sealed class Capture : IDisposable {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Caps {
        public ushort mid, pid; public uint version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string name;
        public uint formats; public ushort channels, reserved;
    }
    [StructLayout(LayoutKind.Sequential, Pack=2)] struct Format {
        public ushort tag, channels; public uint rate, bytesPerSec;
        public ushort align, bits, extra;
    }
    [StructLayout(LayoutKind.Sequential)] struct Header {
        public IntPtr data; public uint length, recorded; public UIntPtr user;
        public uint flags, loops; public IntPtr next; public UIntPtr reserved;
    }
    [DllImport("winmm.dll")] static extern uint waveInGetNumDevs();
    [DllImport("winmm.dll", CharSet=CharSet.Unicode)] static extern uint waveInGetDevCapsW(UIntPtr id, out Caps caps, uint size);
    [DllImport("winmm.dll")] static extern uint waveInOpen(out IntPtr handle, uint id, ref Format fmt, IntPtr cb, IntPtr instance, uint flags);
    [DllImport("winmm.dll")] static extern uint waveInPrepareHeader(IntPtr h, IntPtr p, uint size);
    [DllImport("winmm.dll")] static extern uint waveInUnprepareHeader(IntPtr h, IntPtr p, uint size);
    [DllImport("winmm.dll")] static extern uint waveInAddBuffer(IntPtr h, IntPtr p, uint size);
    [DllImport("winmm.dll")] static extern uint waveInStart(IntPtr h);
    [DllImport("winmm.dll")] static extern uint waveInReset(IntPtr h);
    [DllImport("winmm.dll")] static extern uint waveInClose(IntPtr h);
    IntPtr handle; IntPtr[] headers = new IntPtr[4], data = new IntPtr[4];
    bool[] prepared = new bool[4];
    uint size = (uint)Marshal.SizeOf(typeof(Header));
    public int Received;
    DateTime lastData;
    public static string[] DeviceNames() {
        List<string> names = new List<string>();
        for(uint i=0; i<waveInGetNumDevs(); i++) {
            Caps cap; Check(waveInGetDevCapsW((UIntPtr)i, out cap, (uint)Marshal.SizeOf(typeof(Caps))), "Device enumeration"); names.Add(cap.name);
        }
        return names.ToArray();
    }
    static void Check(uint result, string op) { if (result != 0) throw new Exception(op + ": WinMM error " + result); }
    public void Open(string microphone) {
        try {
            uint chosen = uint.MaxValue;
            string[] names = DeviceNames();
            for (uint i=0; i<names.Length; i++) {
                if (String.IsNullOrEmpty(microphone) ? names[i].IndexOf("AirPods", StringComparison.OrdinalIgnoreCase)>=0 : names[i] == microphone) {
                    if(chosen != uint.MaxValue) throw new Exception("Multiple matching microphones. Select a unique device in Settings.");
                    chosen=i;
                }
            }
            if (chosen == uint.MaxValue) throw new Exception("Microphone not found. Connect AirPods, allow desktop microphone access in Windows, and check Settings.");
            Program.Log("Selected microphone: " + names[chosen]);
            Format f = new Format {tag=1, channels=1, rate=16000, bytesPerSec=32000, align=2, bits=16};
            Check(waveInOpen(out handle, chosen, ref f, IntPtr.Zero, IntPtr.Zero, 0), "Open AirPods microphone");
            for (int i=0; i<4; i++) {
                data[i]=Marshal.AllocHGlobal(3200); headers[i]=Marshal.AllocHGlobal((int)size);
                Header hdr = new Header {data=data[i], length=3200};
                Marshal.StructureToPtr(hdr, headers[i], false);
                Check(waveInPrepareHeader(handle, headers[i], size), "Prepare buffer"); prepared[i]=true;
                Check(waveInAddBuffer(handle, headers[i], size), "Queue buffer");
            }
            Check(waveInStart(handle), "Start microphone");
            lastData = DateTime.UtcNow;
            Program.Log("ON: AirPods capture active; audio discarded, never saved or transmitted");
        } catch { Dispose(); throw; }
    }
    public void Pump() {
        for(int i=0; i<4; i++) if(headers[i]!=IntPtr.Zero) {
            Header hdr=(Header)Marshal.PtrToStructure(headers[i], typeof(Header));
            if((hdr.flags & 1)!=0) { if(hdr.recorded>0) { Received++; lastData = DateTime.UtcNow; } Check(waveInAddBuffer(handle, headers[i], size), "Recycle buffer"); }
        }
        if(handle != IntPtr.Zero && DateTime.UtcNow-lastData > TimeSpan.FromSeconds(5)) throw new Exception("Microphone stopped delivering audio; reconnect the device.");
    }
    public void Dispose() {
        if(handle!=IntPtr.Zero) {
            Check(waveInReset(handle), "Reset microphone");
            for(int i=0;i<4;i++) if(prepared[i]) { Check(waveInUnprepareHeader(handle,headers[i],size),"Release buffer"); prepared[i]=false; }
            Check(waveInClose(handle), "Close microphone"); handle=IntPtr.Zero;
            Program.Log("OFF: AirPods microphone released");
        }
        for(int i=0;i<4;i++) {
            if(headers[i]!=IntPtr.Zero) { Marshal.FreeHGlobal(headers[i]); headers[i]=IntPtr.Zero; }
            if(data[i]!=IntPtr.Zero) { Marshal.FreeHGlobal(data[i]); data[i]=IntPtr.Zero; }
        }
    }
}

sealed class ModeContext : ApplicationContext {
    sealed class Hotkeys : NativeWindow, IDisposable {
        [DllImport("user32.dll", SetLastError=true)] static extern bool RegisterHotKey(IntPtr h,int id,uint mods,uint key);
        [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h,int id);
        public event Action<int> Pressed;
        public Hotkeys(Settings config) {
            CreateHandle(new CreateParams());
            // Ctrl + Alt + F9 toggle; F10 status; F11 off. MOD_NOREPEAT.
            int[] shortcuts = { config.ToggleKey, config.StatusKey, config.OffKey };
            for(int i=0;i<3;i++) if(!RegisterHotKey(Handle,i+1,0x4000 | config.Modifiers,(uint)shortcuts[i])) {
                int error=Marshal.GetLastWin32Error(); Dispose();
                throw new Exception("Hotkey unavailable: "+ config.Shortcut(shortcuts[i])+" (error "+error+"). Open Settings and choose another shortcut.");
            }
        }
        protected override void WndProc(ref Message m) { if(m.Msg==0x312 && Pressed!=null) Pressed(m.WParam.ToInt32()); base.WndProc(ref m); }
        public void Dispose() { for(int i=1;i<=3;i++) UnregisterHotKey(Handle,i); DestroyHandle(); }
    }
    Capture capture; Hotkeys keys; NotifyIcon tray; System.Windows.Forms.Timer timer;
    EventWaitHandle settingsRequest;
    bool showingSettings;
    SpeechSynthesizer voice;
    public ModeContext(bool openSettings) {
        try { voice=new SpeechSynthesizer(); } catch { }
        settingsRequest = new EventWaitHandle(false,EventResetMode.AutoReset,"Local\\AirPodsQuickMode.Settings");
        tray=new NotifyIcon {Icon=System.Drawing.SystemIcons.Application, Text="AirPods Quick Mode: OFF", Visible=true};
        tray.DoubleClick+=delegate { ShowSettings(); };
        RebuildMenu();
        timer=new System.Windows.Forms.Timer {Interval=250};
        timer.Tick+=delegate {
            if(settingsRequest.WaitOne(0)) ShowSettings();
            if(capture!=null) try { capture.Pump(); } catch(Exception e) { Stop(); Program.Log("ERROR "+e); Notify(Program.T("Mikrofon bağlantısı kesildi. Hızlı mod kapatıldı.","Microphone disconnected. Quick mode is off.")); }
        }; timer.Start();
        try { BindKeys(); } catch(Exception e) { Program.Log("ERROR "+e); MessageBox.Show(e.Message,"AirPods Quick Mode"); openSettings=true; }
        Program.Log("READY: mode initially OFF; version 0.1.0");
        Say(Program.T("AirPods hızlı mod hazır. Açmak için ","AirPods Quick Mode ready. To enable, press ") + Program.Config.Shortcut(Program.Config.ToggleKey));
        if(openSettings) settingsRequest.Set();
    }
    void BindKeys() { keys=new Hotkeys(Program.Config); keys.Pressed+=OnKey; }
    void RebuildMenu() {
        ContextMenuStrip old = tray.ContextMenuStrip;
        ContextMenuStrip menu=new ContextMenuStrip();
        menu.Items.Add(Program.T("Hızlı modu aç / kapat","Toggle quick mode")+" ("+Program.Config.Shortcut(Program.Config.ToggleKey)+")",null,delegate { Toggle(); });
        menu.Items.Add(Program.T("Durumu oku","Read status")+" ("+Program.Config.Shortcut(Program.Config.StatusKey)+")",null,delegate { Status(); });
        menu.Items.Add(Program.T("Hızlı modu kapat","Turn quick mode off")+" ("+Program.Config.Shortcut(Program.Config.OffKey)+")",null,delegate { DisableMode(); });
        menu.Items.Add(Program.T("Ayarlar…","Settings…"),null,delegate { ShowSettings(); });
        menu.Items.Add(Program.T("Günlük klasörünü aç","Open log folder"),null,delegate { Process.Start("explorer.exe", Program.DataPath); });
        menu.Items.Add(Program.T("Çıkış (otomatik yeniden başlar)","Exit (automatic restart if installed)"),null,delegate { ExitThread(); });
        tray.ContextMenuStrip=menu; if(old!=null) old.Dispose();
    }
    void ShowSettings() {
        if(showingSettings) return;
        showingSettings=true;
        try {
            using(SettingsDialog dialog = new SettingsDialog(Program.Config)) {
                if(dialog.ShowDialog() != DialogResult.OK) return;
                Stop();
                Settings previous=Program.Config;
                if(keys!=null) { keys.Dispose(); keys=null; }
                try {
                    Program.Config=dialog.Result; BindKeys(); Program.Config.Save(); RebuildMenu();
                    Say(Program.T("Ayarlar kaydedildi. Hızlı mod kapalı.","Settings saved. Quick mode is off."));
                } catch(Exception e) {
                    if(keys!=null) { keys.Dispose(); keys=null; }
                    Program.Config=previous;
                    try { BindKeys(); } catch(Exception restore) { Program.Log("ERROR restoring shortcuts: "+restore); }
                    MessageBox.Show(e.Message,"AirPods Quick Mode",MessageBoxButtons.OK,MessageBoxIcon.Error);
                }
            }
        } finally { showingSettings=false; }
    }
    void Say(string s) { if(voice!=null && Program.Config.SpokenFeedback) try { voice.SpeakAsyncCancelAll(); voice.SpeakAsync(s); } catch { } }
    void Notify(string s) { Say(s); tray.ShowBalloonTip(5000,"AirPods Quick Mode",s,ToolTipIcon.Info); }
    void OnKey(int id) { if(id==1) Toggle(); else if(id==2) Status(); else if(id==3) DisableMode(); }
    void DisableMode() { Stop(); Program.Log("OFF requested; hotkeys remain active"); Say(Program.T("Hızlı mod kapalı.","Quick mode off.")); }
    void Stop() { if(capture!=null) { capture.Dispose(); capture=null; } if(timer!=null) timer.Interval=250; tray.Text="AirPods Quick Mode: OFF"; }
    void Toggle() {
        try {
            if(capture!=null) { Stop(); Say(Program.T("Hızlı mod kapalı.","Quick mode off.")); }
            else { Capture c=new Capture(); c.Open(Program.Config.Microphone); capture=c; timer.Interval=50; tray.Text="AirPods Quick Mode: ON"; Say(Program.T("Hızlı mod açık.","Quick mode on.")); }
        } catch(Exception e) { Program.Log("ERROR "+e); Notify(Program.T("Hızlı mod açılamadı. AirPods bağlantısını ve Ayarlar'ı kontrol edin.","Could not enable quick mode. Check the AirPods connection and Settings.")); }
    }
    void Status() { Say(capture!=null ? Program.T("Hızlı mod açık.","Quick mode on.") : Program.T("Hızlı mod kapalı.","Quick mode off.")); Program.Log(capture!=null ? "STATUS ON" : "STATUS OFF"); }
    protected override void ExitThreadCore() {
        timer.Stop(); Stop(); if(keys!=null) keys.Dispose(); settingsRequest.Dispose(); tray.Visible=false; tray.Dispose(); timer.Dispose();
        if(voice!=null) voice.Dispose(); Program.Log("EXIT"); base.ExitThreadCore();
    }
}

sealed class SettingsDialog : Form {
    public Settings Result;
    ComboBox microphone, toggle, status, off, modifiers, language;
    CheckBox speech;
    static ComboBox Choices(object[] values) {
        ComboBox box = new ComboBox { DropDownStyle=ComboBoxStyle.DropDownList, Dock=DockStyle.Fill };
        box.Items.AddRange(values); return box;
    }
    public SettingsDialog(Settings c) {
        Text=Program.T("AirPods Quick Mode — Ayarlar","AirPods Quick Mode — Settings");
        StartPosition=FormStartPosition.CenterScreen; MinimumSize=new System.Drawing.Size(620,520);
        Size=new System.Drawing.Size(700,560); AutoScaleMode=AutoScaleMode.Font;
        TableLayoutPanel layout = new TableLayoutPanel {Dock=DockStyle.Fill, Padding=new Padding(16), ColumnCount=2, AutoScroll=true};
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,40)); layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,60));
        Controls.Add(layout);
        Label help=new Label {Text=Program.T("Hızlı mod, kulaklık mikrofonunu açarak konuşma profilini tetikler. Ses kalitesi düşebilir ve pil daha hızlı tükenebilir. Mikrofon sesi kaydedilmez veya gönderilmez. Yeniden başlatıldığında mod kapalıdır.","Quick mode opens the headset microphone to request its call profile. Audio quality may drop and battery use may increase. Microphone audio is never recorded or transmitted. Mode starts off after every restart."),AutoSize=true,Dock=DockStyle.Fill,MaximumSize=new System.Drawing.Size(640,0)};
        layout.Controls.Add(help,0,0); layout.SetColumnSpan(help,2); layout.RowCount=1;
        List<object> devices=new List<object>(); devices.Add(Program.T("Otomatik: AirPods","Automatic: AirPods"));
        devices.AddRange(global::Capture.DeviceNames());
        if(!String.IsNullOrEmpty(c.Microphone) && !devices.Contains(c.Microphone)) devices.Add(c.Microphone);
        microphone=Choices(devices.ToArray()); microphone.SelectedIndex=String.IsNullOrEmpty(c.Microphone)?0:devices.IndexOf(c.Microphone);
        AddRow(layout,Program.T("&Mikrofon","&Microphone"),microphone);
        object[] functionKeys=new object[24]; for(int i=0;i<24;i++) functionKeys[i]="F"+(i+1);
        modifiers=Choices(new object[] {"Ctrl+Alt", "Ctrl+Shift", "Alt+Shift", "Ctrl+Alt+Shift"});
        modifiers.SelectedIndex=Array.IndexOf(new uint[]{3,6,5,7},c.Modifiers);
        AddRow(layout,Program.T("&Kısayol tuşları","Shortcut &modifiers"),modifiers);
        toggle=Choices(functionKeys); toggle.SelectedIndex=c.ToggleKey-(int)Keys.F1; AddRow(layout,Program.T("&Aç / kapat","&Toggle"),toggle);
        status=Choices(functionKeys); status.SelectedIndex=c.StatusKey-(int)Keys.F1; AddRow(layout,Program.T("&Durumu oku","&Read status"),status);
        off=Choices(functionKeys); off.SelectedIndex=c.OffKey-(int)Keys.F1; AddRow(layout,Program.T("Modu &kapat","Turn &off"),off);
        language=Choices(new object[]{"Türkçe","English"}); language.SelectedIndex=c.Language=="tr"?0:1; AddRow(layout,Program.T("&Dil","&Language"),language);
        speech=new CheckBox {Text=Program.T("&Sesli bildirimler","&Spoken feedback"),Checked=c.SpokenFeedback,AutoSize=true};
        layout.Controls.Add(speech,0,layout.RowCount); layout.SetColumnSpan(speech,2); layout.RowCount++;
        FlowLayoutPanel buttons=new FlowLayoutPanel {Dock=DockStyle.Fill,AutoSize=true};
        Button save=new Button {Text=Program.T("Kaydet","Save"),AutoSize=true};
        save.Click+=delegate {
            Result=new Settings {Microphone=microphone.SelectedIndex==0?"":(string)microphone.SelectedItem,ToggleKey=(int)Keys.F1+toggle.SelectedIndex,StatusKey=(int)Keys.F1+status.SelectedIndex,OffKey=(int)Keys.F1+off.SelectedIndex,Modifiers=new uint[]{3,6,5,7}[modifiers.SelectedIndex],Language=language.SelectedIndex==0?"tr":"en",SpokenFeedback=speech.Checked};
            try { Result.Validate(); DialogResult=DialogResult.OK; Close(); } catch(Exception e) { MessageBox.Show(this,e.Message,Text); }
        };
        Button cancel=new Button {Text=Program.T("İptal","Cancel"),AutoSize=true,DialogResult=DialogResult.Cancel};
        buttons.Controls.Add(save); buttons.Controls.Add(cancel); layout.Controls.Add(buttons,0,layout.RowCount); layout.SetColumnSpan(buttons,2);
        AcceptButton=save; CancelButton=cancel;
    }
    static void AddRow(TableLayoutPanel layout,string label,Control control) {
        int row=layout.RowCount; layout.RowCount++;
        layout.Controls.Add(new Label {Text=label,AutoSize=true,Anchor=AnchorStyles.Left},0,row);
        control.AccessibleName=label.Replace("&",""); layout.Controls.Add(control,1,row);
    }
}
