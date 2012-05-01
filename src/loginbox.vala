
public const string LIGHT_WINDOW_STYLE = """
    .content-view-window {
        background-image:none;
        background-color:@bg_color;
        
        border-radius: 6px;
        
        border-width:1px;
        border-style: solid;
        border-color: alpha (#000, 0.25);
    }
""";

public class LoginBox : GtkClutter.Actor {
    
    public const string DEFAULT_WALLPAPER = "/usr/share/backgrounds/16.jpg";
    
    public LightDM.User current_user { get; private set; }
    public string      current_session { get; private set; }
    
    public Gtk.Image    avatar;
    public Gtk.Label    username;
    public Gtk.Entry    password;
    public Gtk.Button   login;
    public Gtk.Button   settings;
    
    public Clutter.Texture background;   //not added to the box
    public Clutter.Texture background_s; //double buffered!
    
    Granite.Drawing.BufferSurface buffer;
    int shadow_blur = 15;
    int shadow_x    = 0;
    int shadow_y    = 0;
    double shadow_alpha = 0.3;
    
    LightDM.Greeter greeter;
    
    public void set_wallpaper (string path) {
        this.background_s.opacity = 0;
        try {
            this.background_s.set_from_file (path);
        } catch (Error e) { warning (e.message); }
        this.background_s.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:255).
            completed.connect ( () => {
            try {
                this.background.set_from_file (path);
            } catch (Error e) { warning (e.message); }
            this.background_s.opacity = 0;
        });
    }
    
    public LoginBox (LightDM.Greeter greeter) {
        
        this.greeter = greeter;
        
        this.reactive = true;
        
        this.background = new Clutter.Texture.from_file (DEFAULT_WALLPAPER);
        this.background_s = new Clutter.Texture ();
        this.background_s.opacity = 0;
        this.background.load_async = true;
        this.background_s.load_async = true;
        
        this.avatar   = new Gtk.Image ();
        this.username = new Gtk.Label ("");
        this.password = new Gtk.Entry ();
        this.login    = new Gtk.Button.with_label (_("Login"));
        this.settings = new Gtk.Button ();
        var space     = new Gtk.Label ("");
        
        username.hexpand = true;
        username.halign  = Gtk.Align.START;
        username.ellipsize = Pango.EllipsizeMode.END;
        space.vexpand    = true;
        login.halign     = Gtk.Align.END;
        login.width_request = 140;
        settings.halign  = Gtk.Align.END;
        settings.add (new Gtk.Image.from_icon_name ("application-menu-symbolic", Gtk.IconSize.MENU));
        password.caps_lock_warning = true;
        password.set_visibility (false);
        password.key_release_event.connect ( (e) => {
            if (e.keyval == Gdk.Key.Return) {
                login.clicked ();
                return true;
            } else 
                return false;
        });
        
        var grid = new Gtk.Grid ();
        
        grid.attach (avatar,   0, 0, 1, 3);
        grid.attach (settings, 1, 0, 1, 1);
        grid.attach (username, 1, 1, 1, 1);
        grid.attach (password, 1, 2, 1, 1);
        grid.attach (space,    0, 3, 1, 1);
        grid.attach (login,    0, 4, 2, 1);
        
        grid.margin = 26;
        grid.row_spacing = 2;
        grid.column_spacing = 12;
        
        /*session choose popover*/
        this.settings.clicked.connect ( () => {
            var pop = new Granite.Widgets.PopOver ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            ((Gtk.Box)pop.get_content_area ()).add (box);
            
            var but = new Gtk.RadioButton.with_label (null, LightDM.
                get_sessions ().nth_data (0).name);
            box.pack_start (but, false);
            if (LightDM.get_sessions ().nth_data (0).key == current_session)
                but.active = true;
            but.toggled.connect ( () => {
                this.current_session = LightDM.get_sessions ().nth_data (0).key;
            });
            
            for (var i=1;i<LightDM.get_sessions ().length ();i++) {
                var rad = new Gtk.RadioButton.with_label_from_widget (but, 
                    LightDM.get_sessions ().nth_data (i).name);
                box.pack_start (rad, false);
                if (LightDM.get_sessions ().nth_data (i).key == current_session)
                    rad.active = true;
                var identifier = LightDM.get_sessions ().nth_data (i).key;
                rad.toggled.connect ( () => { this.current_session = identifier; });
            }
            
            pop.move_to_widget (this.settings);
            pop.present ();
            pop.show_all ();
            pop.run ();
            pop.destroy ();
        });
        
        /*draw the window stylish!*/
        var css = new Gtk.CssProvider ();
        try {
            css.load_from_data (LIGHT_WINDOW_STYLE, -1);
        } catch (Error e) { warning (e.message); }
        
        var draw_ref = new Gtk.Window ();
        draw_ref.get_style_context ().add_class ("content-view-window");
        draw_ref.get_style_context ().add_provider (css, Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);
        
        var w = -1; var h = -1;
        this.get_widget ().size_allocate.connect ( () => {
            if (w == this.get_widget ().get_allocated_width () && 
                h == this.get_widget ().get_allocated_height ())
                return;
            w = this.get_widget ().get_allocated_width ();
            h = this.get_widget ().get_allocated_height ();
            
            this.buffer = new Granite.Drawing.BufferSurface (w, h);
            
            this.buffer.context.rectangle (shadow_blur + shadow_x, 
                shadow_blur + shadow_y, w - shadow_blur*2 + shadow_x, h - shadow_blur*2 + shadow_y);
            this.buffer.context.set_source_rgba (0, 0, 0, shadow_alpha);
            this.buffer.context.fill ();
            this.buffer.exponential_blur (shadow_blur / 2);
            
            draw_ref.get_style_context ().render_activity (this.buffer.context, shadow_blur + shadow_x, 
                shadow_blur + shadow_y, w - shadow_blur*2 + shadow_x, h - shadow_blur*2 + shadow_y);
        });
        
        this.get_widget ().draw.connect ( (ctx) => {
            ctx.rectangle (0, 0, this.get_widget ().get_allocated_width (), this.get_widget ().get_allocated_height ());
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.set_source_rgba (0, 0, 0, 0);
            ctx.fill ();
            
            ctx.set_source_surface (buffer.surface, 0, 0);
            ctx.paint ();
            
            return false;
        });
        
        ((Gtk.Container)this.get_widget ()).add (grid);
        this.get_widget ().show_all ();
        this.get_widget ().get_style_context ().add_class ("content-view");
    }
    
    public static string get_user_markup (LightDM.User user) {
        var first_name = user.real_name.substring (0, user.real_name.index_of (" "));
        return "<span face='Open Sans Light' font='32'>"+first_name+"</span>"+
            "    <span face='Open Sans Normal' font='16'>"+user.name+"</span>";
    }
    
    public void set_user (LightDM.User ?user) { //guest if null
        this.password.text = "";
        if (user == null) {
            this.username.set_markup ("<span face='Open Sans Light' font='24'>"+
                "Guest session</span>");
            this.avatar.set_from_icon_name ("avatar-default", Gtk.IconSize.DIALOG);
            this.set_wallpaper (DEFAULT_WALLPAPER);
            
            this.current_user = null;
            this.current_session = greeter.default_session_hint;
            this.password.set_sensitive (false);
        } else {
            this.username.set_markup (get_user_markup (user));
            
            this.avatar.set_from_file (user.image);
            this.set_wallpaper (user.background);
            
            this.current_user = user;
            this.current_session = user.session;
            this.password.set_sensitive (true);
        }
    }
}

