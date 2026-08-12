#!/usr/bin/env bash

set -e

# ==============================================================================
# CONFIGURACIÓN
# ==============================================================================
GITHUB_USER="Matias01jr"
GITHUB_REPO="NeonCraft"
BRANCH="main"
IMAGE_NAME="mc_neon.png"

# URL directa del tema Sweet en GitHub
THEME_URL="https://github.com/EliverLara/Sweet/releases/download/v6.0/Sweet-Ambar-Blue-Dark.tar.xz"
THEME_FILE="Sweet-Ambar-Blue-Dark.tar.xz"
THEME_NAME="Sweet-Ambar-Blue-Dark"
# ==============================================================================

CONFIG_DIR="$HOME/.config/mc_neon_theme"
BACKUP_FILE="$CONFIG_DIR/backup.cfg"
WALLPAPER_PATH="$CONFIG_DIR/$IMAGE_NAME"
THEME_DIR="$HOME/.themes"

WALLPAPER_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/refs/heads/${BRANCH}/${IMAGE_NAME}"

mkdir -p "$CONFIG_DIR" "$THEME_DIR"

check_dependencies() {
    sudo sed -i '/cdrom:/s/^/#/' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true

    local pkgs=()
    command -v fzf >/dev/null 2>&1 || pkgs+=(fzf)
    command -v curl >/dev/null 2>&1 || pkgs+=(curl)
    command -v tar >/dev/null 2>&1 || pkgs+=(tar)
    command -v xz >/dev/null 2>&1 || pkgs+=(xz-utils)
    
    if [ ${#pkgs[@]} -ne 0 ]; then
        echo "[i] Instalando dependencias necesarias (${pkgs[*]})..."
        sudo apt-get update -qq && sudo apt-get install -y -qq "${pkgs[@]}"
    fi
}

detect_de() {
    local de="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
    de="$(echo "$de" | tr '[:upper:]' '[:lower:]')"
    
    case "$de" in
        *gnome*|*ubuntu*) echo "gnome" ;;
        *xfce*)          echo "xfce" ;;
        *kde*|*plasma*)  echo "kde" ;;
        *cinnamon*)      echo "cinnamon" ;;
        *mate*)          echo "mate" ;;
        *)               echo "unknown" ;;
    esac
}

backup_current_theme() {
    local de
    de=$(detect_de)
    echo "DE=$de" > "$BACKUP_FILE"

    case "$de" in
        gnome)
            echo "WALLPAPER=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null)" >> "$BACKUP_FILE"
            echo "GTK_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" >> "$BACKUP_FILE"
            ;;
        cinnamon)
            echo "WALLPAPER=$(gsettings get org.cinnamon.desktop.background picture-uri 2>/dev/null)" >> "$BACKUP_FILE"
            echo "GTK_THEME=$(gsettings get org.cinnamon.desktop.interface gtk-theme 2>/dev/null)" >> "$BACKUP_FILE"
            ;;
        mate)
            echo "WALLPAPER=$(gsettings get org.mate.background picture-filename 2>/dev/null)" >> "$BACKUP_FILE"
            echo "GTK_THEME=$(gsettings get org.mate.interface gtk-theme 2>/dev/null)" >> "$BACKUP_FILE"
            ;;
        xfce)
            local prop
            prop=$(xfconf-query -c xfce4-desktop -l | grep -E 'last-image|image-path' | head -n 1)
            echo "XFCE_PROP=$prop" >> "$BACKUP_FILE"
            echo "WALLPAPER=$(xfconf-query -c xfce4-desktop -p "$prop" 2>/dev/null)" >> "$BACKUP_FILE"
            echo "GTK_THEME=$(xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null)" >> "$BACKUP_FILE"
            ;;
    esac
}

apply_theme() {
    local de
    de=$(detect_de)
    
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "[+] Guardando respaldo del tema actual..."
        backup_current_theme
    fi

    # 1. Descargar Fondo
    echo "[+] Descargando fondo de pantalla..."
    curl -fsSL -o "$WALLPAPER_PATH" "$WALLPAPER_URL" || true

    # 2. Descargar e instalar tema Sweet-Ambar-Blue-Dark
    echo "[+] Descargando paquete de tema $THEME_NAME..."
    if curl -fsSL -o "$CONFIG_DIR/$THEME_FILE" -L "$THEME_URL"; then
        echo "[+] Extrayendo tema en $THEME_DIR..."
        tar -xf "$CONFIG_DIR/$THEME_FILE" -C "$THEME_DIR/"
        echo "[✔] Tema $THEME_NAME instalado con éxito."
    else
        echo "[!] Error al descargar el tema $THEME_NAME."
    fi

    # 3. Aplicar tema según el escritorio
    echo "[+] Aplicando $THEME_NAME y fondo en $de..."
    case "$de" in
        gnome)
            gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_PATH"
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_PATH"
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
            gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"
            ;;
        cinnamon)
            gsettings set org.cinnamon.desktop.background picture-uri "file://$WALLPAPER_PATH"
            gsettings set org.cinnamon.desktop.interface gtk-theme "$THEME_NAME"
            ;;
        mate)
            gsettings set org.mate.background picture-filename "$WALLPAPER_PATH"
            gsettings set org.mate.interface gtk-theme "$THEME_NAME"
            ;;
        xfce)
            for prop in $(xfconf-query -c xfce4-desktop -l | grep -E 'last-image|image-path'); do
                xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER_PATH" 2>/dev/null || true
            done
            xfconf-query -c xsettings -p /Net/ThemeName -s "$THEME_NAME"
            ;;
        kde)
            plasma-apply-wallpaperimage "$WALLPAPER_PATH" 2>/dev/null || true
            ;;
    esac

    # 4. Refresco de pantalla
    echo "[+] Refrescando interfaz..."
    case "$de" in
        xfce) xfdesktop --reload 2>/dev/null || true ;;
        cinnamon) cinnamon --replace >/dev/null 2>&1 & ;;
        gnome) busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Restarting...")' >/dev/null 2>&1 || true ;;
    esac

    # 5. Configuración adicional de barra
    echo
    read -p "¿Deseas reubicar la barra/menú al estilo moderno central/neón? (s/N): " resp < /dev/tty
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        case "$de" in
            gnome) gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM' 2>/dev/null || true ;;
            cinnamon) gsettings set org.cinnamon panel-zone-icon-sizes '[{"panelId":1,"left":24,"center":32,"right":24}]' 2>/dev/null || true ;;
            xfce) xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -s 1 2>/dev/null || true ;;
        esac
    fi

    echo -e "\n[✔] Tema $THEME_NAME y fondo aplicados correctamente."
    read -p "Presiona Enter para continuar..." < /dev/tty
}

restore_theme() {
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "\n[!] No hay respaldo previo guardado en $BACKUP_FILE."
        read -p "Presiona Enter para continuar..." < /dev/tty
        return
    fi

    echo "[+] Restaurando configuración previa..."
    source "$BACKUP_FILE"

    case "$DE" in
        gnome)
            [ -n "$WALLPAPER" ] && gsettings set org.gnome.desktop.background picture-uri "$WALLPAPER"
            [ -n "$GTK_THEME" ] && gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
            ;;
        cinnamon)
            [ -n "$WALLPAPER" ] && gsettings set org.cinnamon.desktop.background picture-uri "$WALLPAPER"
            [ -n "$GTK_THEME" ] && gsettings set org.cinnamon.desktop.interface gtk-theme "$GTK_THEME"
            ;;
        mate)
            [ -n "$WALLPAPER" ] && gsettings set org.mate.background picture-filename "$WALLPAPER"
            [ -n "$GTK_THEME" ] && gsettings set org.mate.interface gtk-theme "$GTK_THEME"
            ;;
        xfce)
            if [ -n "$WALLPAPER" ]; then
                for prop in $(xfconf-query -c xfce4-desktop -l | grep -E 'last-image|image-path'); do
                    xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER" 2>/dev/null || true
                done
                xfdesktop --reload 2>/dev/null || true
            fi
            [ -n "$GTK_THEME" ] && xfconf-query -c xsettings -p /Net/ThemeName -s "$GTK_THEME"
            ;;
    esac

    echo -e "\n[✔] Configuración original restaurada."
    read -p "Presiona Enter para continuar..." < /dev/tty
}

main_menu() {
    check_dependencies

    while true; do
        clear
        local options="1) Aplicar tema
2) Restaurar tema anterior"
        
        local selection
        selection=$(fzf --height 30% --reverse --header="=== NEON THEME MANAGER ===" --prompt="Selecciona una opción: " < /dev/tty <<< "$options")

        case "$selection" in
            "1)"*|1) apply_theme ;;
            "2)"*|2) restore_theme ;;
            "") echo "Saliendo..."; exit 0 ;;
        esac
    done
}

main_menu
