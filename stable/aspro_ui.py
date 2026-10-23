#!/usr/bin/env python3
"""ASPRO Stable — reduced GTK UI derived from the proven AS2K 240x36 shell."""
import os
import sys
import shutil
import subprocess
from pathlib import Path
import gi
gi.require_version("Gtk","3.0")
gi.require_version("Gdk","3.0")
gi.require_version("GdkPixbuf","2.0")
from gi.repository import Gtk,Gdk,GdkPixbuf,GLib

HOME=Path.home()
CONFIG=Path(os.environ.get("ASPRO_CONFIG_DIR",HOME/".config/aspro"))
CONTROL=Path(os.environ["ASPRO_UI_CONTROL_FILE"])
EVENT=Path(os.environ["ASPRO_UI_EVENT_FILE"])
FRAME=Path(os.environ["ASPRO_UI_FRAME_FILE"])
W,H=240,36
FG=(92,83,88)
BG=(138,146,148)


def frame_to_rgb(raw):
    """Expand MAME's 240x36 monochrome framebuffer using C-backed bytes ops."""
    if len(raw)!=W*H:
        raise ValueError("Invalid ASPRO LCD framebuffer length")
    rgb=raw.replace(b"\x00",bytes(BG)).replace(b"\x01",bytes(FG))
    if len(rgb)!=W*H*3:
        raise ValueError("Invalid ASPRO LCD pixel values")
    return rgb


class ProWindow(Gtk.ApplicationWindow):
    def __init__(self,app):
        super().__init__(application=app,title="ASPRO Emulator")
        self.set_border_width(0)
        self.set_default_size(920,440)
        self.connect("key-press-event",self.key_down)
        self.connect("key-release-event",self.key_up)
        self.connect("delete-event",lambda *_:False)
        self.events_at=0
        self.frame_stamp=-1
        self.frame_cache=None
        self.pc=False
        self.pix=GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB,False,8,W,H)
        self.pix.fill((BG[0]<<24)|(BG[1]<<16)|(BG[2]<<8)|255)
        root=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=0)
        self.add(root)
        self.header=Gtk.Label(label="ASPRO Emulator — PC: OFF")
        self.header.set_xalign(0.0)
        self.header.set_margin_start(10)
        self.header.set_margin_top(7)
        self.header.set_margin_bottom(7)
        root.pack_start(self.header,False,False,0)
        bar=Gtk.MenuBar()
        root.pack_start(bar,False,False,0)
        def menu(title):
            item=Gtk.MenuItem(label=title)
            submenu=Gtk.Menu()
            item.set_submenu(submenu)
            bar.append(item)
            return submenu
        def item(m,title,callback):
            x=Gtk.MenuItem(label=title)
            x.connect("activate",callback)
            m.append(x)
        files=menu("Archivo")
        item(files,"Abrir ROM Pro…",self.open_rom)
        item(files,"Abrir payload bootstrap…",self.open_payload)
        item(files,"Arranque normal",lambda *_:self.command("BOOTSTRAP CLEAR"))
        files.append(Gtk.SeparatorMenuItem())
        item(files,"Guardar captura de pantalla…",self.screenshot)
        item(files,"Salir",lambda *_:self.close())
        machine=menu("Máquina")
        item(machine,"Reiniciar AlphaSmart Pro",lambda *_:self.command("MACHINE RESET"))
        pc=Gtk.CheckMenuItem(label="PC conectado")
        pc.connect("toggled",self.toggle_pc)
        machine.append(pc)
        view=menu("Ver")
        for zoom in (1,2,3,4):
            item(view,f"Escala LCD {zoom}×",lambda _,n=zoom:self.set_zoom(n))
        self.full=Gtk.CheckMenuItem(label="Pantalla completa")
        self.full.connect("toggled",lambda i:self.fullscreen() if i.get_active() else self.unfullscreen())
        view.append(self.full)
        cfg=menu("Configuración")
        item(cfg,"Abrir carpeta de ROM y payload",self.open_config)
        help_menu=menu("Ayuda")
        item(help_menu,"Acerca de ASPRO Emulator",self.about)
        bezel=Gtk.Frame()
        bezel.set_shadow_type(Gtk.ShadowType.IN)
        bezel.set_margin_top(12)
        bezel.set_margin_bottom(6)
        bezel.set_margin_start(12)
        bezel.set_margin_end(12)
        self.lcd=Gtk.DrawingArea()
        self.lcd.set_size_request(W*3,H*3)
        self.lcd.connect("draw",self.draw_lcd)
        bezel.add(self.lcd)
        root.pack_start(bezel,True,True,0)
        keybox=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL,spacing=4)
        keybox.set_margin_start(10);keybox.set_margin_bottom(8)
        for label,key in [("Esc","ESC"),("F1","F1"),("F2","F2"),("F3","F3"),("F4","F4"),("F5","F5"),("F6","F6"),("F7","F7"),("F8","F8"),("Clear","CLEAR"),("Send","SEND"),("Enter","ENTER")]:
            b=Gtk.Button(label=label)
            b.connect("clicked",lambda _b,k=key:self.command("KEY "+k))
            keybox.pack_start(b,False,False,0)
        root.pack_start(keybox,False,False,0)
        self.status=Gtk.Label(label="ASPRO Stable — esperando al núcleo")
        self.status.set_xalign(0)
        self.status.set_margin_start(10)
        self.status.set_margin_bottom(6)
        root.pack_start(self.status,False,False,0)
        GLib.timeout_add(30,self.poll_lcd)
        GLib.timeout_add(60,self.poll_events)

    def command(self,text):
        try:
            with CONTROL.open("a",encoding="utf8") as f:f.write(text+"\n")
            self.status.set_text(text)
        except OSError as e:self.status.set_text(str(e))

    def draw_lcd(self,_area,cr):
        rect=self.lcd.get_allocation()
        scale=max(1,min(rect.width/W,rect.height/H))
        cr.save()
        cr.translate((rect.width-W*scale)/2,(rect.height-H*scale)/2)
        cr.scale(scale,scale)
        Gdk.cairo_set_source_pixbuf(cr,self.pix,0,0)
        cr.get_source().set_filter(0)
        cr.paint()
        cr.restore()
        return False

    def set_zoom(self,n):
        self.lcd.set_size_request(W*n,H*n)
        self.resize(W*n+32,H*n+175)

    def poll_lcd(self):
        try:
            stat=FRAME.stat()
            if stat.st_mtime_ns==self.frame_stamp or stat.st_size!=W*H:
                return True
            raw=FRAME.read_bytes()
            if len(raw)!=W*H:
                return True
            if raw==self.frame_cache:
                self.frame_stamp=stat.st_mtime_ns
                return True
            rgb=frame_to_rgb(raw)
            next_pix=GdkPixbuf.Pixbuf.new_from_bytes(
                GLib.Bytes.new(rgb),GdkPixbuf.Colorspace.RGB,False,8,W,H,W*3)
            self.pix=next_pix
            self.frame_cache=raw
            self.frame_stamp=stat.st_mtime_ns
            self.lcd.queue_draw()
        except (OSError,ValueError):
            # Ignore a frame being rewritten; the next GTK tick retries.
            pass
        return True

    def poll_events(self):
        try:
            size=EVENT.stat().st_size
            if size<self.events_at:self.events_at=0
            if size>self.events_at:
                with EVENT.open(encoding="utf8",errors="replace") as f:
                    f.seek(self.events_at)
                    data=f.read()
                    self.events_at=f.tell()
                for line in data.splitlines():
                    if line.startswith("STATUS\t"):self.status.set_text(line.split("\t",1)[1])
                    elif line.startswith("BOOT_ACK\t"):
                        self.status.set_text(line.replace("\t"," "))
                    elif line.startswith("SEND_READY\t"):
                        self.status.set_text("PC Send capturado: "+line.split("\t",1)[1])
        except OSError:pass
        return True

    def key_name(self,event):
        raw=Gdk.keyval_name(event.keyval) or ""
        aliases={"Escape":"ESC","BackSpace":"BACKSPACE","Tab":"TAB",
          "Return":"RETURN","KP_Enter":"ENTER","space":"SPACE","Caps_Lock":"CAPSLOCK",
          "Shift_L":"LSHIFT","Shift_R":"RSHIFT","Control_L":"LCTRL","Control_R":"RCTRL",
          "Alt_L":"LALT","Alt_R":"RALT","Left":"LEFT","Right":"RIGHT",
          "Up":"UP","Down":"DOWN","Home":"HOME","End":"END",
          "grave":"GRAVE","minus":"MINUS","equal":"EQUALS","comma":"COMMA",
          "period":"PERIOD","slash":"SLASH","bracketleft":"LBRACKET",
          "bracketright":"RBRACKET","backslash":"BACKSLASH","semicolon":"SEMICOLON",
          "apostrophe":"QUOTE"}
        if raw in aliases:return aliases[raw]
        if raw.startswith("F") and raw[1:].isdigit() and 1<=int(raw[1:])<=8:return raw
        if len(raw)==1 and raw.isascii() and raw.isalnum():return raw.upper()
        return None

    def key_down(self,_widget,event):
        k=self.key_name(event)
        if k:self.command("KEYDOWN "+k)
        return False
    def key_up(self,_widget,event):
        k=self.key_name(event)
        if k:self.command("KEYUP "+k)
        return False
    def toggle_pc(self,item):
        self.pc=item.get_active()
        self.command("PC ON" if self.pc else "PC OFF")
        self.header.set_text("ASPRO Emulator — PC: "+("ON" if self.pc else "OFF"))
    def choose(self,title):
        dialog=Gtk.FileChooserDialog(title,self,Gtk.FileChooserAction.OPEN,
             ("Cancelar",Gtk.ResponseType.CANCEL,"Abrir",Gtk.ResponseType.OK))
        choice=None
        if dialog.run()==Gtk.ResponseType.OK:choice=Path(dialog.get_filename())
        dialog.destroy()
        return choice
    def open_rom(self,*_):
        path=self.choose("ROM original AlphaSmart Pro — 32768 bytes")
        if path is None:return
        if path.stat().st_size!=32768:
            self.status.set_text("ROM inválida: se requieren 32768 bytes");return
        CONFIG.mkdir(parents=True,exist_ok=True)
        dest=CONFIG/"firmware.bin"
        shutil.copy2(path,dest)
        dest.chmod(0o600)
        self.status.set_text("ROM instalada en ASPRO privado. Cierra y vuelve a abrir para aplicar.")
    def open_payload(self,*_):
        path=self.choose("Payload HC11D0 para bootstrap (1..192 bytes)")
        if path is None:return
        if not 1<=path.stat().st_size<=192:
            self.status.set_text("Payload inválido: límite 192 bytes");return
        CONFIG.mkdir(parents=True,exist_ok=True)
        dest=CONFIG/"payload0_pro.bin"
        shutil.copy2(path,dest)
        dest.chmod(0o600)
        self.command("BOOTSTRAP_FILE "+str(dest))
    def screenshot(self,*_):
        dialog=Gtk.FileChooserDialog("Guardar LCD",self,Gtk.FileChooserAction.SAVE,
            ("Cancelar",Gtk.ResponseType.CANCEL,"Guardar",Gtk.ResponseType.OK))
        if dialog.run()==Gtk.ResponseType.OK:
            self.pix.savev(dialog.get_filename(),"png",[],[])
        dialog.destroy()
    def open_config(self,*_):
        CONFIG.mkdir(parents=True,exist_ok=True)
        subprocess.Popen(["xdg-open",str(CONFIG)])
    def about(self,*_):
        d=Gtk.AboutDialog(transient_for=self,modal=True)
        d.set_program_name("ASPRO Stable")
        d.set_comments("Interfaz reducida AlphaSmart Pro, adaptada de AS2K. Bootstrap SCI y conexión PC.")
        d.run();d.destroy()

class ProApplication(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.customretrostuff.aspro")
    def do_activate(self):
        w=self.props.active_window or ProWindow(self)
        w.show_all();w.present()

if __name__=="__main__":
    raise SystemExit(ProApplication().run(sys.argv))
