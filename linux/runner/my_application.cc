#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static MyApplication* s_my_application = NULL;
static GtkWindow* s_main_window = NULL;
static GtkStatusIcon* s_tray_icon = NULL;

static gchar* soty_icon_path() {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", NULL);
  if (exe == NULL) {
    return NULL;
  }
  g_autofree gchar* dir = g_path_get_dirname(exe);
  return g_build_filename(dir, "data", "flutter_assets", "assets",
                          "soty_icon.png", NULL);
}

static void tray_open(GtkMenuItem* item, gpointer user_data) {
  if (s_main_window != NULL) {
    gtk_window_deiconify(s_main_window);
    gtk_window_present(s_main_window);
  }
}

static void tray_quit(GtkMenuItem* item, gpointer user_data) {
  g_application_quit(G_APPLICATION(s_my_application));
}

static void tray_on_activate(GtkStatusIcon* icon, gpointer user_data) {
  tray_open(NULL, NULL);
}

static void tray_on_popup_menu(GtkStatusIcon* icon, guint button,
                               guint activate_time, gpointer user_data) {
  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  GtkWidget* menu = gtk_menu_new();
  GtkWidget* open = gtk_menu_item_new_with_label("Open");
  GtkWidget* quit = gtk_menu_item_new_with_label("Quit");
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), open);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu), quit);
  g_signal_connect(open, "activate", G_CALLBACK(tray_open), NULL);
  g_signal_connect(quit, "activate", G_CALLBACK(tray_quit), NULL);
  g_signal_connect(menu, "deactivate", G_CALLBACK(gtk_widget_destroy), NULL);
  gtk_widget_show(open);
  gtk_widget_show(quit);
  gtk_menu_popup(GTK_MENU(menu), NULL, NULL, gtk_status_icon_position_menu,
                 icon, button, activate_time);
  G_GNUC_END_IGNORE_DEPRECATIONS
}

static void setup_tray() {
  if (s_tray_icon != NULL) {
    return;
  }
  g_autofree gchar* icon_path = soty_icon_path();
  if (icon_path == NULL) {
    return;
  }
  g_autoptr(GdkPixbuf) pixbuf = gdk_pixbuf_new_from_file(icon_path, NULL);
  if (pixbuf == NULL) {
    return;
  }
  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  g_autoptr(GdkPixbuf) scaled =
      gdk_pixbuf_scale_simple(pixbuf, 22, 22, GDK_INTERP_BILINEAR);
  s_tray_icon = gtk_status_icon_new_from_pixbuf(scaled);
  if (s_tray_icon != NULL) {
    gtk_status_icon_set_tooltip_text(s_tray_icon, "Soty");
    g_signal_connect(s_tray_icon, "activate", G_CALLBACK(tray_on_activate),
                     NULL);
    g_signal_connect(s_tray_icon, "popup-menu", G_CALLBACK(tray_on_popup_menu),
                     NULL);
    gtk_status_icon_set_visible(s_tray_icon, TRUE);
  }
  G_GNUC_END_IGNORE_DEPRECATIONS
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  s_my_application = self;
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  s_main_window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Soty");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Soty");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autofree gchar* icon_path = soty_icon_path();
  if (icon_path != NULL) {
    gtk_window_set_icon_from_file(window, icon_path, NULL);
  }
  setup_tray();

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
