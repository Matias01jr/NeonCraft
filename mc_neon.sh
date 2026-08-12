#!/usr/bin/env bash

set -e

# ==============================================================================
# CONFIGURACIÓN DE GITHUB
# ==============================================================================
GITHUB_USER="Matias01jr"
GITHUB_REPO="NeonCraft"
BRANCH="main"
IMAGE_NAME="mc_neon.png"
# ==============================================================================

CONFIG_DIR="$HOME/.config/mc_neon_theme"
BACKUP_FILE="$CONFIG_DIR/backup.cfg"
WALLPAPER_PATH="$CONFIG_DIR/$IMAGE_NAME"

WALLPAPER_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/refs/heads/${BRANCH}/${IMAGE_NAME}"

mkdir -p "$CONFIG_DIR"

check_dependencies() {
    # Desactivar repositorios CD-ROM en entornos Live para evitar errores de apt
    sudo sed -i '/cdrom:/s/^/#/' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true

    local pkgs=()
    command -v fzf >/dev/null 2>&1 || pkgs+=(fzf)
    command -v curl >/dev/null 2>&1 || pkgs+=(curl)
    
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
            echo "COLOR_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" >> "$BACKUP_FILE"
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
        kde)
            echo "GTK_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" >> "$BACKUP_FILE"
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

    echo "[+] Descargando fondo $IMAGE_NAME desde GitHub..."
    
    if curl -fsSL -o "$WALLPAPER_PATH" "$WALLPAPER_URL"; then
        echo "[✔] Imagen descargada correctamente."
    else
        echo "[!] Error al descargar la imagen desde $WALLPAPER_URL"
        read -p "Presiona Enter para continuar..." < /dev/tty
        return
    fi

    echo "[+] Aplicando estilo Neón Colorido en $de..."
    case "$de" in
        gnome)
            gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_PATH"
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_PATH"
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
            gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
            ;;
        cinnamon)
            gsettings set org.cinnamon.desktop.background picture-uri "file://$WALLPAPER_PATH"
            gsettings set org.cinnamon.desktop.interface gtk-theme 'Mint-Y-Dark-Purple' 2>/dev/null || \
            gsettings set org.cinnamon.desktop.interface gtk-theme 'Adwaita-dark'
            ;;
        mate)
            gsettings set org.mate.background picture-filename "$WALLPAPER_PATH"
            gsettings set org.mate.interface gtk-theme 'Mint-Y-Dark-Purple' 2>/dev/null || \
            gsettings set org.mate.interface gtk-theme 'Yaru-dark'
            ;;
        xfce)
            for prop in $(xfconf-query -c xfce4-desktop -l | grep -E 'last-image|image-path'); do
                xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER_PATH" 2>/dev/null || true
            done
            xfconf-query -c xsettings -p /Net/ThemeName -s "Mint-Y-Dark-Purple" 2>/dev/null || \
            xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"
            ;;
        kde)
            plasma-apply-wallpaperimage "$WALLPAPER_PATH" 2>/dev/null || true
            ;;
    esac

    # Recarga inmediata de pantalla
    echo "[+] Forzando recarga inmediata del escritorio..."
    case "$de" in
        xfce)
            xfdesktop --reload 2>/dev/null || xfdesktop -r 2>/dev/null || true
            ;;
        cinnamon)
            cinnamon --replace >/dev/null 2>&1 &
            ;;
        gnome)
            busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Restarting...")' >/dev/null 2>&1 || true
            ;;
    esac

    # Pregunta interactiva redirigida a la terminal
    echo
    read -p "¿Deseas reubicar la barra/menú al estilo moderno central/neón? (s/N): " resp < /dev/tty
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        case "$de" in
            gnome)
                gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM' 2>/dev/null || true
                ;;
            cinnamon)
                gsettings set org.cinnamon panel-zone-icon-sizes '[{"panelId":1,"left":24,"center":32,"right":24}]' 2>/dev/null || true
                ;;
            xfce)
                xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -s 1 2>/dev/null || true
                ;;
        esac
    fi

    echo -e "\n[✔] Tema Minecraft Neón aplicado con éxito."
    read -p "Presiona Enter para continuar..." < /dev/tty
}

restore_theme() {
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "\n[!] No se encontró ningún respaldo guardado en $BACKUP_FILE."
        read -p "Presiona Enter para continuar..." < /dev/tty
        return
    fi

    echo "[+] Restaurando tema anterior..."
    source "$BACKUP_FILE"

    case "$DE" in
        gnome)
            [ -n "$WALLPAPER" ] && gsettings set org.gnome.desktop.background picture-uri "$WALLPAPER"
            [ -n "$COLOR_SCHEME" ] && gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME"
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

    echo -e "\n[✔] Configuración anterior restaurada."
    read -p "Presiona Enter para continuar..." < /dev/tty
}

main_menu() {
    check_dependencies

    while true; do
        clear
        local options="1) Aplicar Tema Minecraft Neón\n2) Restaurar Tema Anterior\n0) Salir"
        
        # Redirección < /dev/tty para permitir entrada de teclado en fzf dentro de curl | bash
        local selection
        selection=$(echo -e "$options" | fzf --height 40% --reverse --header="=== MINECRAFT NEON THEME MANAGER ===" --prompt="Selecciona una opción: " < /dev/tty)

        case "$selection" in
            "1)"*|1)
                apply_theme
                ;;
            "2)"*|2)
                restore_theme
                ;;
            "0)"*|0|"")
                echo "Saliendo..."
                exit 0
                ;;
        esac
    done
}

main_menu
