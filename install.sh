#!/bin/bash

# ======================================================================================
# PROFESSIONAL ARCH LINUX INSTALLER
# Автор: Gemini (на основе запроса пользователя)
# Описание: Интерактивный TUI установщик в стиле archinstall (v1.2)
# Улучшения: Автоматический выбор видеодрайвера и установка всех основных драйверов для ПК.
# ======================================================================================

# --- Глобальные переменные и настройки ---
LOG_FILE="/var/log/archinstall.log"
CONFIG_FILE="/tmp/arch_install_config.json"
MOUNT_POINT="/mnt"
DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0

# Цвета для вывода в консоль (не в dialog)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Переменные для хранения выбора пользователя
SELECTED_PROFILE=""
CHOSEN_PACKAGES=""
TIMEZONE=""
LOCALE_GEN_LIST=""
ENABLE_MULTILIB="false"
AUR_HELPER=""
SWAP_SIZE_GB="2" # Default swap size
USE_SWAP="false"
PART_BOOT=""
PART_ROOT=""
PART_SWAP=""

# Установка UTF-8 локали для корректного отображения
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Убедимся, что скрипт запущен от root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root.${NC}"
   exit 1
fi

# Проверка наличия dialog, установка если нет
if ! command -v dialog &> /dev/null; then
    echo -e "${GREEN}Installing dependency: dialog...${NC}"
    pacman -Sy --noconfirm dialog &> /dev/null
fi

# Проверка наличия reflector
if ! command -v reflector &> /dev/null; then
    echo -e "${GREEN}Installing dependency: reflector...${NC}"
    pacman -S --noconfirm reflector &> /dev/null
fi

# Проверка наличия curl
if ! command -v curl &> /dev/null; then
    echo -e "${GREEN}Installing dependency: curl...${NC}"
    pacman -S --noconfirm curl &> /dev/null
fi

# Функция для логирования (используется вместо exec)
log() {
    echo "$@" >> ${LOG_FILE}
}

# Очистка экрана и подготовка
clear

# --- Локализация ---
declare -A TXT

# Функция переключения языка
set_language() {
    local lang=$1
    if [[ "$lang" == "RU" ]]; then
        TXT[TITLE]="Установщик Arch Linux"
        TXT[BACKTITLE]="Профессиональный скрипт установки (v1.2)"
        TXT[WELCOME]="Добро пожаловать в установщик Arch Linux.\n\nЭтот мастер поможет вам настроить и установить систему.\nНавигация: Стрелки, Tab, Enter."
        TXT[DISK_SELECT]="Выберите диск для установки:"
        TXT[DISK_WARN]="ВНИМАНИЕ! ВСЕ ДАННЫЕ НА ВЫБРАННОМ ДИСКЕ БУДУТ УДАЛЕНЫ!"
        TXT[SCHEME_SELECT]="Выберите схему разметки:"
        TXT[GPU_DETECT]="Обнаружена видеокарта:"
        TXT[GPU_SELECT]="Выберите драйвер видеокарты (или пропустите, если автоматический выбор не сработал):"
        TXT[DE_SELECT]="Выберите окружение рабочего стола:"
        TXT[KEY_SEARCH]="Введите поисковый запрос для раскладки (например 'ru'):"
        TXT[KEY_SELECT]="Выберите раскладку:"
        TXT[KEY_CONFIRM]="Выбранные раскладки:"
        TXT[HOSTNAME]="Введите имя компьютера (hostname):"
        TXT[ROOT_PASS]="Введите пароль для ROOT:"
        TXT[USER_NAME]="Введите имя нового пользователя:"
        TXT[USER_PASS]="Введите пароль пользователя:"
        TXT[PROFILE_SELECT]="Выберите профиль установки:"
        TXT[BOOTLOADER]="Выберите загрузчик:"
        TXT[TIMEZONE_SEARCH]="Введите регион для поиска часового пояса (например, 'Europe'):"
        TXT[LOCALE_SELECT]="Выберите основную системную локаль (LANG):"
        TXT[EXTRAS_CHECK]="Дополнительные пакеты и опции:"
        TXT[SWAP_PROMPT]="Введите желаемый размер SWAP-раздела в ГБ (0 для пропуска):"
        TXT[FINAL_CONFIRM]="Начать установку? Это действие необратимо."
        TXT[INSTALLING]="Установка..."
        TXT[DONE]="Установка завершена! Перезагрузить систему?"
        TXT[ERROR]="Ошибка"
        TXT[YES]="Да"
        TXT[NO]="Нет"
        TXT[CANCEL]="Отмена"
        TXT[AUTO_EXT4]="Автоматически (wipe, ext4)"
        TXT[AUTO_BTRFS]="Автоматически (wipe, btrfs)"
        TXT[MANUAL]="Ручная разметка (cfdisk/cgdisk)"
        TXT[ERR_PART]="Ошибка разметки или монтирования диска. Проверьте диск и повторите попытку."
        TXT[ERR_PACSTRAP]="Ошибка при выполнении pacstrap. Проверьте подключение к сети."
        TXT[ERR_CHROOT]="Ошибка при выполнении настройки системы внутри chroot."
    else
        TXT[TITLE]="Arch Linux Installer"
        TXT[BACKTITLE]="Professional Install Script (v1.2)"
        TXT[WELCOME]="Welcome to Arch Linux Installer.\n\nThis wizard will guide you through the process.\nNavigation: Arrows, Tab, Enter."
        TXT[DISK_SELECT]="Select target disk:"
        TXT[DISK_WARN]="WARNING! ALL DATA ON SELECTED DISK WILL BE ERASED!"
        TXT[SCHEME_SELECT]="Select partitioning scheme:"
        TXT[GPU_DETECT]="Detected GPU:"
        TXT[GPU_SELECT]="Select Graphics Driver (or skip if auto-detection worked):"
        TXT[DE_SELECT]="Select Desktop Environment:"
        TXT[KEY_SEARCH]="Enter search term for layout (e.g., 'us'):"
        TXT[KEY_SELECT]="Select keyboard layout:"
        TXT[KEY_CONFIRM]="Selected layouts:"
        TXT[HOSTNAME]="Enter Hostname:"
        TXT[ROOT_PASS]="Enter ROOT password:"
        TXT[USER_NAME]="Enter new Username:"
        TXT[USER_PASS]="Enter User password:"
        TXT[PROFILE_SELECT]="Select Install Profile:"
        TXT[BOOTLOADER]="Select Bootloader:"
        TXT[TIMEZONE_SEARCH]="Enter region for timezone search (e.g., 'Europe'):"
        TXT[LOCALE_SELECT]="Select primary system locale (LANG):"
        TXT[EXTRAS_CHECK]="Extra packages and options:"
        TXT[SWAP_PROMPT]="Enter desired SWAP partition size in GB (0 to skip):"
        TXT[FINAL_CONFIRM]="Start installation? This is irreversible."
        TXT[INSTALLING]="Installing..."
        TXT[DONE]="Installation complete! Reboot now?"
        TXT[ERROR]="Error"
        TXT[YES]="Yes"
        TXT[NO]="No"
        TXT[CANCEL]="Cancel"
        TXT[AUTO_EXT4]="Automatic (wipe, ext4)"
        TXT[AUTO_BTRFS]="Automatic (wipe, btrfs)"
        TXT[MANUAL]="Manual partitioning (cfdisk/cgdisk)"
        TXT[ERR_PART]="Disk partitioning or mounting failed. Check disk and retry."
        TXT[ERR_PACSTRAP]="Pacstrap failed. Check network connection."
        TXT[ERR_CHROOT]="Chroot system configuration failed."
    fi
}

# --- Вспомогательные функции UI ---

# Показ сообщения
show_msg() {
    log "MSG: $1"
    dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[TITLE]}" --msgbox "$1" 10 50
}

# Показ вопроса (Да/Нет)
show_yesno() {
    log "YESNO: $1"
    dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[TITLE]}" --yesno "$1" 10 50
    return $?
}

# Обработка критической ошибки
show_error() {
    clear
    echo -e "${RED}--- CRITICAL ERROR ---${NC}"
    echo -e "${RED}$1${NC}"
    echo "Check the log file: $LOG_FILE"
    log "ERROR: $1"
    sleep 5
    dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[ERROR]}" --msgbox "$1" 10 70
    exit 1
}

# Ввод текста
get_input() {
    local prompt="$1"
    local result_var="$2"
    local init_val="$3"
    exec 3>&1
    value=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[TITLE]}" --inputbox "$prompt" 10 50 "$init_val" 2>&1 1>&3)
    exit_code=$?
    exec 3>&-
    log "INPUT: $prompt = $value"
    eval $result_var=\$value
    return $exit_code
}

# Ввод пароля
get_password() {
    local prompt="$1"
    local result_var="$2"
    exec 3>&1
    value=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[TITLE]}" --insecure --passwordbox "$prompt" 10 50 2>&1 1>&3)
    exit_code=$?
    exec 3>&-
    log "PASSWORD INPUT: $prompt"
    eval $result_var=\$value
    return $exit_code
}

# Функция для отображения прогресса
show_progress() {
    local total=$1
    local current=$2
    local message="$3"
    local percentage=$(( current * 100 / total ))
    
    log "PROGRESS: $percentage% - $message"
    echo "$percentage" | dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[INSTALLING]}" --gauge "$message" 10 70 0
}

# --- Шаги установки ---

# 1. Выбор языка
step_language() {
    exec 3>&1
    LANG_CHOICE=$(dialog --backtitle "Arch Installer" --title "Language / Язык" --menu "Select Interface Language / Выберите язык интерфейса" 12 50 2 \
        "RU" "Русский" \
        "EN" "English" 2>&1 1>&3)
    exec 3>&-
    
    if [[ -z "$LANG_CHOICE" ]]; then exit 1; fi
    log "Selected language: $LANG_CHOICE"
    set_language "$LANG_CHOICE"
}

# 1.5. Выбор профиля
step_profile() {
    local default_item="1"
    
    exec 3>&1
    SELECTED_PROFILE=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[PROFILE_SELECT]}" --default-item "$default_item" --menu "Choose System Profile:" 15 60 4 \
        "Desktop" "Полная установка с графическим окружением (DE/WM)" \
        "Minimal" "Минимальная консольная система (Base + Utils)" \
        "Server" "Серверная конфигурация (SSH, Web)" \
        "Xorg" "Базовая графическая система (Xorg + драйверы)" 2>&1 1>&3)
    exec 3>&-
    
    log "Selected profile: $SELECTED_PROFILE"
    if [[ -z "$SELECTED_PROFILE" ]]; then return 1; fi
}


# 2. Выбор диска
step_disk() {
    # Получаем список дисков с размером и моделью
    # Формат lsblk: NAME SIZE MODEL
    local disks=()
    while read -r name size model; do
        # Исключаем разделы, loop-устройства и CD-ROM
        if [[ ! "$name" =~ "part" ]] && [[ ! "$name" =~ "loop" ]] && [[ ! "$name" =~ "sr0" ]]; then
            disks+=("/dev/$name" "$size - $model")
        fi
    done < <(lsblk -d -n -o NAME,SIZE,MODEL)

    exec 3>&1
    SELECTED_DISK=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[DISK_SELECT]}" --menu "${TXT[DISK_WARN]}" 15 60 5 "${disks[@]}" 2>&1 1>&3)
    exec 3>&-

    log "Selected disk: $SELECTED_DISK"
    if [[ -z "$SELECTED_DISK" ]]; then return 1; fi
}

# 3. Схема разметки
step_partition_scheme() {
    exec 3>&1
    PARTITION_SCHEME=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[SCHEME_SELECT]}" --menu "" 12 50 3 \
        "1" "${TXT[AUTO_EXT4]}" \
        "2" "${TXT[AUTO_BTRFS]}" \
        "3" "${TXT[MANUAL]}" 2>&1 1>&3)
    exec 3>&-
    
    log "Selected partition scheme: $PARTITION_SCHEME"
    if [[ -z "$PARTITION_SCHEME" ]]; then return 1; fi
}

# 3.5. Настройка SWAP
step_swap_config() {
    get_input "${TXT[SWAP_PROMPT]}" SWAP_SIZE_GB "2"
    
    if [[ ! "$SWAP_SIZE_GB" =~ ^[0-9]+$ ]] || [[ "$SWAP_SIZE_GB" -lt 0 ]]; then
        show_msg "${TXT[ERROR]}: Некорректный размер SWAP. Установлено 2 ГБ по умолчанию."
        SWAP_SIZE_GB="2"
    fi

    if [[ "$SWAP_SIZE_GB" -gt 0 ]]; then
        USE_SWAP="true"
    else
        USE_SWAP="false"
    fi
    log "SWAP size: $SWAP_SIZE_GB GB, Use SWAP: $USE_SWAP"
    return 0
}


# 4. Драйверы видео (с автоматическим определением)
step_gpu() {
    if [[ "$SELECTED_PROFILE" == "Minimal" ]] || [[ "$SELECTED_PROFILE" == "Server" ]]; then
        GPU_DRIVER="none"
        log "GPU driver: none (profile: $SELECTED_PROFILE)"
        return 0
    fi

    GPU_INFO=$(lspci | grep -E "VGA|3D")
    AUTO_DRIVER=""
    
    # Попытка автоматического определения
    if echo "$GPU_INFO" | grep -qi "NVIDIA" && ! echo "$GPU_INFO" | grep -qi "Intel\|AMD"; then
        # Четкая NVIDIA (не гибрид)
        AUTO_DRIVER="1"
    elif echo "$GPU_INFO" | grep -qi "AMD" && ! echo "$GPU_INFO" | grep -qi "Intel\|NVIDIA"; then
        # Четкая AMD (не гибрид)
        AUTO_DRIVER="3"
    elif echo "$GPU_INFO" | grep -qi "Intel" && ! echo "$GPU_INFO" | grep -qi "AMD\|NVIDIA"; then
        # Четкая Intel (не гибрид)
        AUTO_DRIVER="4"
    elif echo "$GPU_INFO" | grep -qi "NVIDIA" && echo "$GPU_INFO" | grep -qi "Intel\|AMD"; then
        # Гибридная графика, выбираем опцию PRIME
        AUTO_DRIVER="5"
    fi

    if [[ -n "$AUTO_DRIVER" ]]; then
        show_msg "${TXT[GPU_DETECT]}\n$GPU_INFO\n\nАвтоматически выбран вариант №$AUTO_DRIVER."
        GPU_DRIVER="$AUTO_DRIVER"
        log "Auto-detected GPU driver: $GPU_DRIVER"
        return 0
    fi
    
    # Если автоматическое определение не сработало или было слишком общим, показываем меню
    local default_item="1"

    exec 3>&1
    GPU_DRIVER=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[GPU_SELECT]}" --default-item "$default_item" --menu "${TXT[GPU_DETECT]}\n$GPU_INFO" 18 70 7 \
        "1" "NVIDIA (Proprietary - nvidia, utils)" \
        "2" "NVIDIA (Open Source - nouveau)" \
        "3" "AMD (Mesa, Vulkan, DDX)" \
        "4" "Intel (Mesa, Vulkan, DDX)" \
        "5" "Hybrid (NVIDIA + Intel/AMD PRIME)" \
        "6" "Generic / VM (VirtualBox, QEMU)" \
        "7" "Skip / Пропустить" 2>&1 1>&3)
    exec 3>&-
    
    log "Selected GPU driver: $GPU_DRIVER"
}

# 5. Выбор DE/WM (только если выбран Desktop)
step_de() {
    if [[ "$SELECTED_PROFILE" != "Desktop" ]]; then
        CHOSEN_DE="none"
        log "DE: none (profile: $SELECTED_PROFILE)"
        return 0
    fi

    exec 3>&1
    CHOSEN_DE=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[DE_SELECT]}" --menu "Select environment:" 20 70 9 \
        "kde" "KDE Plasma (Full - plasma-meta)" \
        "gnome" "GNOME (Full - gnome)" \
        "xfce" "XFCE4 (Lightweight)" \
        "cinnamon" "Cinnamon" \
        "mate" "MATE" \
        "i3" "i3-wm (Tiling WM)" \
        "sway" "Sway (Wayland Tiling)" \
        "none" "Shell only (No GUI)" 2>&1 1>&3)
    exec 3>&-
    
    log "Selected DE: $CHOSEN_DE"
}

# 6. Раскладки клавиатуры (Живой поиск)
step_keyboard() {
    KEYMAPS_SELECTED=()
    
    # Предопределенный список популярных раскладок
    local common_layouts=(
        "us" "English (US)"
        "ru" "Russian"
        "de" "German"
        "fr" "French"
        "es" "Spanish"
        "it" "Italian"
        "pt" "Portuguese"
        "pl" "Polish"
        "ua" "Ukrainian"
        "gb" "English (UK)"
        "jp" "Japanese"
        "cn" "Chinese"
        "kr" "Korean"
        "br" "Brazilian"
        "latam" "Latin American"
        "ara" "Arabic"
        "tr" "Turkish"
        "se" "Swedish"
        "no" "Norwegian"
        "dk" "Danish"
        "fi" "Finnish"
        "cz" "Czech"
        "sk" "Slovak"
        "hu" "Hungarian"
        "ro" "Romanian"
        "bg" "Bulgarian"
        "gr" "Greek"
        "il" "Hebrew"
        "in" "Indian"
        "th" "Thai"
        "vn" "Vietnamese"
    )
    
    while true; do
        # Показываем меню с популярными раскладками
        exec 3>&1
        local selection=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[KEY_SELECT]}" \
            --menu "Select keyboard layout:" 20 50 15 "${common_layouts[@]}" 2>&1 1>&3)
        local exit_code=$?
        exec 3>&-
        
        if [[ $exit_code -ne 0 ]]; then
            # Если пользователь отменил и не выбрал ни одной раскладки
            if [[ ${#KEYMAPS_SELECTED[@]} -eq 0 ]]; then
                KEYMAPS_SELECTED=("us")
            fi
            break
        fi
        
        if [[ -n "$selection" ]]; then
            KEYMAPS_SELECTED+=("$selection")
            if ! show_yesno "${TXT[KEY_CONFIRM]} ${KEYMAPS_SELECTED[*]}. Add more layouts?"; then
                break
            fi
        fi
    done
    
    if [[ ${#KEYMAPS_SELECTED[@]} -eq 0 ]]; then
        KEYMAPS_SELECTED=("us")
    fi
    
    # Выбор комбинации переключения
    exec 3>&1
    TOGGLE_KEY=$(dialog --backtitle "${TXT[BACKTITLE]}" --menu "Toggle combination:" 15 50 5 \
        "grp:alt_shift_toggle" "Alt+Shift" \
        "grp:ctrl_shift_toggle" "Ctrl+Shift" \
        "grp:win_space_toggle" "Win+Space" \
        "grp:caps_toggle" "Caps Lock" 2>&1 1>&3)
    exec 3>&-
    
    if [[ -z "$TOGGLE_KEY" ]]; then
        TOGGLE_KEY="grp:alt_shift_toggle"
    fi
    
    log "Selected keymaps: ${KEYMAPS_SELECTED[*]}, Toggle: $TOGGLE_KEY"
}

# 7. Настройка системы (Hostname, Users)
step_system_config() {
    get_input "${TXT[HOSTNAME]}" TARGET_HOSTNAME "archlinux"
    
    while true; do
        get_password "${TXT[ROOT_PASS]}" ROOT_PASSWORD
        get_password "Confirm ROOT password:" ROOT_PASSWORD_2
        [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_2" && -n "$ROOT_PASSWORD" ]] && break
        show_msg "Passwords do not match or empty!"
    done

    get_input "${TXT[USER_NAME]}" NEW_USER "user"
    
    while true; do
        get_password "${TXT[USER_PASS]}" USER_PASSWORD
        get_password "Confirm User password:" USER_PASSWORD_2
        [[ "$USER_PASSWORD" == "$USER_PASSWORD_2" && -n "$USER_PASSWORD" ]] && break
        show_msg "Passwords do not match or empty!"
    done
    
    log "Hostname: $TARGET_HOSTNAME, User: $NEW_USER"
}

# 8. Настройка часового пояса и локали
step_timezone_locale() {
    local search_term=""
    
    # 8.1. Часовой пояс с поиском
    while true; do
        get_input "${TXT[TIMEZONE_SEARCH]}" search_term "Europe"
        if [[ $? -ne 0 ]]; then break; fi

        local tz_list_file=$(mktemp)
        find /usr/share/zoneinfo/ -type f | sed 's/\/usr\/share\/zoneinfo\///' | grep -v 'Etc' | grep -v 'posix' | grep -i "$search_term" > "$tz_list_file"
        
        local menu_items=()
        while read -r line; do
             menu_items+=("$line" "")
        done < "$tz_list_file"
        rm "$tz_list_file"

        if [[ ${#menu_items[@]} -eq 0 ]]; then
            show_msg "Ничего не найдено / Nothing found"
            continue
        fi

        exec 3>&1
        TIMEZONE=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "Timezone Selection" --menu "Select Timezone:" 20 60 10 "${menu_items[@]}" 2>&1 1>&3)
        exec 3>&-
        [[ -n "$TIMEZONE" ]] && break
    done
    
    if [[ -z "$TIMEZONE" ]]; then TIMEZONE="UTC"; fi

    # 8.2. Локали
    # Используем чек-лист для выбора локалей, которые будут сгенерированы
    local locales=(
        "en_US.UTF-8 UTF-8" "English (US)" "ON"
        "ru_RU.UTF-8 UTF-8" "Русский" "ON"
        "de_DE.UTF-8 UTF-8" "Deutsch" "OFF"
        "fr_FR.UTF-8 UTF-8" "Français" "OFF"
    )
    
    exec 3>&1
    LOCALE_GEN_SELECTIONS=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "Locale Selection" --checklist "${TXT[LOCALE_SELECT]}" 15 60 5 "${locales[@]}" 2>&1 1>&3)
    exec 3>&-
    
    # Сохраняем выбранные локали как список
    LOCALE_GEN_LIST=$(echo "$LOCALE_GEN_SELECTIONS" | tr ' ' '\n')

    # Выбираем основную локаль LANG
    local locale_list_for_lang=()
    for item in $LOCALE_GEN_LIST; do
        # Удаляем кавычки
        item=$(echo $item | tr -d '"')
        # Разделяем на имя и описание
        name=$(echo $item | awk '{print $1}')
        locale_list_for_lang+=("$name" "")
    done

    exec 3>&1
    LANG_VAR=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "Main Locale (LANG)" --menu "Set primary LANG variable (e.g. en_US.UTF-8):" 15 50 5 "${locale_list_for_lang[@]}" 2>&1 1>&3)
    exec 3>&-
    
    if [[ -z "$LANG_VAR" ]]; then LANG_VAR="en_US.UTF-8"; fi
    
    log "Timezone: $TIMEZONE, LANG: $LANG_VAR, Locales: $LOCALE_GEN_LIST"
}

# 9. Дополнительные пакеты и опции
step_packages_extras() {
    local packages_list=(
        "firefox" "Веб-браузер Firefox" "ON"
        "chromium" "Веб-браузер Chromium" "OFF"
        "git" "Система контроля версий" "ON"
        "vim" "Текстовый редактор Vim" "ON"
        "nano" "Текстовый редактор Nano" "OFF"
        "htop" "Монитор процессов" "ON"
        "multilib" "Включить репозиторий Multilib (для 32-бит)" "OFF"
        "yay" "AUR Helper: Yay (после установки)" "OFF"
        "paru" "AUR Helper: Paru (после установки)" "OFF"
    )

    exec 3>&1
    local selections=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[EXTRAS_CHECK]}" --checklist "Select optional features and packages:" 20 70 10 "${packages_list[@]}" 2>&1 1>&3)
    exec 3>&-

    # Парсинг результатов
    CHOSEN_PACKAGES=""
    for item in $selections; do
        item=$(echo $item | tr -d '"')
        case "$item" in
            "multilib") ENABLE_MULTILIB="true" ;;
            "yay") AUR_HELPER="yay" ;;
            "paru") AUR_HELPER="paru" ;;
            *) CHOSEN_PACKAGES="$CHOSEN_PACKAGES $item" ;;
        esac
    done
    CHOSEN_PACKAGES=$(echo "$CHOSEN_PACKAGES" | xargs) # Удаление лишних пробелов
    
    if [[ "$AUR_HELPER" == "yay" ]] && [[ "$CHOSEN_PACKAGES" == *"paru"* ]]; then
        AUR_HELPER="yay" # Приоритет Yay, если выбрано оба
        CHOSEN_PACKAGES=$(echo "$CHOSEN_PACKAGES" | sed 's/paru//g')
    fi
    
    log "Multilib: $ENABLE_MULTILIB, AUR Helper: $AUR_HELPER, Packages: $CHOSEN_PACKAGES"
}

# 10. Загрузчик
step_bootloader() {
    # Проверка режима загрузки
    if [[ -d /sys/firmware/efi ]]; then
        BOOT_MODE="UEFI"
        exec 3>&1
        BOOTLOADER=$(dialog --backtitle "${TXT[BACKTITLE]}" --title "${TXT[BOOTLOADER]}" --menu "UEFI Detected" 12 50 2 \
            "grub" "GRUB" \
            "systemd-boot" "systemd-boot" 2>&1 1>&3)
        exec 3>&-
    else
        BOOT_MODE="BIOS"
        BOOTLOADER="grub" # Grub - дефолт для BIOS
        show_msg "BIOS Detected. Using GRUB."
    fi
    
    log "Boot mode: $BOOT_MODE, Bootloader: $BOOTLOADER"
}

# --- ФУНКЦИИ УСТАНОВКИ (Back-end) ---

perform_installation() {
    clear
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}       STARTING ARCH LINUX INSTALLATION     ${NC}"
    echo -e "${GREEN}==========================================${NC}"

    # 1. Настройка времени и зеркал
    show_progress 10 1 "Updating system time and mirrorlist..."
    timedatectl set-ntp true >> ${LOG_FILE} 2>&1
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist >> ${LOG_FILE} 2>&1 || show_error "Reflector failed. Check internet connection."
    
    # 2. Партиционирование
    show_progress 10 2 "Partitioning disk $SELECTED_DISK..."
    
    # Очистка диска и сброс монтирований
    umount -R /mnt 2>/dev/null || true
    wipefs -a "$SELECTED_DISK" >> ${LOG_FILE} 2>&1 || show_error "Failed to wipefs on $SELECTED_DISK."

    # 2.1. Определение префиксов разделов
    if [[ "$SELECTED_DISK" == *"nvme"* ]]; then
        PART_PREFIX="p"
    else
        PART_PREFIX=""
    fi
    
    # Счётчик для разделов
    PART_COUNT=1
    START_MB=1 # Начало диска в MiB (с небольшим смещением)

    if [[ "$PARTITION_SCHEME" == "1" ]] || [[ "$PARTITION_SCHEME" == "2" ]]; then
        parted -s "$SELECTED_DISK" mklabel gpt >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mklabel gpt)"

        # 2.2. UEFI/BOOT раздел (512 MiB)
        if [[ "$BOOT_MODE" == "UEFI" ]]; then
            local boot_end=$((START_MB + 512))"MiB"
            parted -s "$SELECTED_DISK" mkpart "EFI" fat32 "$START_MB"MiB "$boot_end" >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (EFI partition)"
            parted -s "$SELECTED_DISK" set "$PART_COUNT" esp on >> ${LOG_FILE} 2>&1
            PART_BOOT="${SELECTED_DISK}${PART_PREFIX}${PART_COUNT}"
            mkfs.fat -F32 "$PART_BOOT" >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mkfs EFI)"
            START_MB=$((START_MB + 513))
            PART_COUNT=$((PART_COUNT + 1))
        fi

        # 2.3. SWAP раздел
        if [[ "$USE_SWAP" == "true" ]]; then
            local swap_end=$((START_MB + (SWAP_SIZE_GB * 1024)))"MiB"
            parted -s "$SELECTED_DISK" mkpart "SWAP" linux-swap "$START_MB"MiB "$swap_end" >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (SWAP partition)"
            parted -s "$SELECTED_DISK" set "$PART_COUNT" swap on >> ${LOG_FILE} 2>&1
            PART_SWAP="${SELECTED_DISK}${PART_PREFIX}${PART_COUNT}"
            mkswap "$PART_SWAP" >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mkswap)"
            START_MB=$((START_MB + (SWAP_SIZE_GB * 1024) + 1))
            PART_COUNT=$((PART_COUNT + 1))
        fi
        
        # 2.4. ROOT раздел (до конца диска)
        parted -s "$SELECTED_DISK" mkpart "ROOT" "$START_MB"MiB 100% >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (ROOT partition)"
        PART_ROOT="${SELECTED_DISK}${PART_PREFIX}${PART_COUNT}"

        # 2.5. Форматирование ROOT и монтирование
        if [[ "$PARTITION_SCHEME" == "1" ]]; then
            mkfs.ext4 -F "$PART_ROOT" >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mkfs ROOT ext4)"
            mount "$PART_ROOT" /mnt >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mount ROOT ext4)"
        else
            mkfs.btrfs -f "$PART_ROOT" >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mkfs ROOT btrfs)"
            mount "$PART_ROOT" /mnt >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mount ROOT btrfs)"
        fi
        
        # 2.6. Монтирование BOOT и активация SWAP
        if [[ "$BOOT_MODE" == "UEFI" ]]; then
            mkdir -p /mnt/boot
            mount "$PART_BOOT" /mnt/boot >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (mount BOOT)"
        fi

        if [[ "$USE_SWAP" == "true" ]]; then
            swapon "$PART_SWAP" >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PART]} (swapon)"
        fi
        
    elif [[ "$PARTITION_SCHEME" == "3" ]]; then
        # MANUAL MODE:
        cfdisk "$SELECTED_DISK"
        if ! show_yesno "Manual partitioning done. Are you sure you have mounted / and /boot/efi (if needed) to /mnt?"; then
            show_error "Installation cancelled due to unconfirmed manual mounting."
        fi
        # При ручной разметке невозможно определить PART_ROOT, что вызовет ошибку в systemd-boot.
        # Для минимальной работы, будем считать, что root на $SELECTED_DISK + 2 (стандартный случай после EFI).
        PART_ROOT="${SELECTED_DISK}${PART_PREFIX}2" 
    fi


    # 3. Установка Base
    show_progress 10 3 "Pacstrap base system (may take time)..."
    local base_packages="base linux linux-firmware base-devel networkmanager sudo dialog"
    
    # Добавляем пакеты в зависимости от профиля
    if [[ "$SELECTED_PROFILE" == "Server" ]]; then
        base_packages="$base_packages openssh"
    elif [[ "$SELECTED_PROFILE" == "Xorg" ]]; then
         base_packages="$base_packages xorg-server xorg-xinit"
    fi
    
    pacstrap /mnt $base_packages >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_PACSTRAP]}"

    # 4. Fstab
    show_progress 10 4 "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab 2>> ${LOG_FILE} || show_error "Failed to generate fstab."

    # 5. Настройка системы внутри Chroot
    show_progress 10 5 "Creating chroot configuration script..."
    
    # 5.1. Установка Multilib, если выбрано
    if [[ "$ENABLE_MULTILIB" == "true" ]]; then
        # Включаем Multilib перед pacman -S внутри chroot
        sed -i '/\[multilib\]/,/Include/s/^#//' /mnt/etc/pacman.conf
    fi
    
    # 5.2. Создание скрипта chroot
    cat <<EOF > /mnt/setup_chroot.sh
#!/bin/bash
# =========================================================================
# CHROOT SCRIPT: FINAL SYSTEM CONFIGURATION AND DRIVER INSTALLATION
# =========================================================================

# Настройка времени и локали
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Генерация локалей
echo "Generating locales..."
for locale in $LOCALE_GEN_LIST; do
    # Удаляем кавычки и добавляем в locale.gen
    # Используем grep -q, чтобы не дублировать, если locale уже есть
    grep -q "\$(echo \$locale | tr -d '\"')" /etc/locale.gen || echo "\$(echo \$locale | tr -d '\"')" >> /etc/locale.gen
done
locale-gen || exit 1 # Критическая ошибка
echo "LANG=$LANG_VAR" > /etc/locale.conf

# Настройка сети и имени
echo "$TARGET_HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $TARGET_HOSTNAME.localdomain $TARGET_HOSTNAME" >> /etc/hosts

# Пароли
echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G wheel,audio,video,storage,optical -s /bin/bash "$NEW_USER"
echo "$NEW_USER:$USER_PASSWORD" | chpasswd
# Включение sudo для группы wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Network
systemctl enable NetworkManager

# Universal PC Drivers (Звук, Bluetooth, Принтеры)
# Установка драйверов для лучшей совместимости с оборудованием
echo "Installing universal PC drivers (Sound, Bluetooth, Printing, etc.)..."
pacman -S --noconfirm --needed alsa-utils pipewire pipewire-alsa pipewire-pulse sof-firmware bluez bluez-utils cups || exit 1

# Включение основных служб для автоматического обнаружения
systemctl enable bluetooth cups

# Video Drivers (Пакеты)
case "$GPU_DRIVER" in
    1) pacman -S --noconfirm --needed nvidia nvidia-utils nvidia-settings ;;
    2) pacman -S --noconfirm --needed xf86-video-nouveau ;;
    3) pacman -S --noconfirm --needed mesa xf86-video-amdgpu vulkan-radeon libva-mesa-driver ;;
    4) pacman -S --noconfirm --needed mesa xf86-video-intel vulkan-intel ;;
    5) pacman -S --noconfirm --needed nvidia nvidia-utils mesa xf86-video-intel prime-run ;;
    6) pacman -S --noconfirm --needed virtualbox-guest-utils mesa-demos ;;
esac

# Desktop Environment (Пакеты и Display Manager)
DM=""
case "$CHOSEN_DE" in
    kde) pacman -S --noconfirm --needed plasma-meta sddm konsole dolphin || exit 1; DM="sddm" ;;
    gnome) pacman -S --noconfirm --needed gnome gdm || exit 1; DM="gdm" ;;
    xfce|i3|sway) pacman -S --noconfirm --needed xfce4 xfce4-goodies lightdm lightdm-gtk-greeter || exit 1; DM="lightdm" ;;
    cinnamon) pacman -S --noconfirm --needed cinnamon lightdm lightdm-gtk-greeter || exit 1; DM="lightdm" ;;
    mate) pacman -S --noconfirm --needed mate lightdm lightdm-gtk-greeter || exit 1; DM="lightdm" ;;
esac

# Включение DM, если он есть
if [[ -n "\$DM" ]]; then
    systemctl enable "\$DM"
fi

# Additional packages
if [[ -n "$CHOSEN_PACKAGES" ]]; then
    pacman -S --noconfirm --needed $CHOSEN_PACKAGES || exit 1
fi

# Bootloader
if [[ "$BOOTLOADER" == "grub" ]]; then
    pacman -S --noconfirm --needed grub efibootmgr || exit 1
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable --recheck || exit 1
    else
        grub-install --target=i386-pc "$SELECTED_DISK" || exit 1
    fi
    grub-mkconfig -o /boot/grub/grub.cfg || exit 1
elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    pacman -S --noconfirm --needed efibootmgr || exit 1
    bootctl --path=/boot install || exit 1
    echo "default arch.conf" > /boot/loader/loader.conf
    echo "timeout 3" >> /boot/loader/loader.conf
    
    # Для systemd-boot требуется UUID корневого раздела.
    # \$PART_ROOT - это переменная извне chroot, которая расширится при создании скрипта.
    ROOT_UUID=\$(blkid -s UUID -o value $PART_ROOT)
    
    cat <<BOOTCONF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=\$ROOT_UUID rw
BOOTCONF
fi

# AUR Helper (Установка как пользователя)
if [[ -n "$AUR_HELPER" ]]; then
    pacman -S --noconfirm --needed git base-devel || exit 1
    
    local aur_dir="/tmp/$AUR_HELPER"
    
    # Установка git как пользователя
    sudo -u $NEW_USER bash <<USR_INSTALL
    cd /tmp
    git clone https://aur.archlinux.org/$AUR_HELPER.git
    cd $AUR_HELPER
    makepkg -si --noconfirm
USR_INSTALL
    
    # Если makepkg не сработал, удаляем папку
    rm -rf \$aur_dir
fi

EOF

    show_progress 10 6 "Entering chroot and configuring system..."
    chmod +x /mnt/setup_chroot.sh
    
    # Запуск скрипта настройки внутри новой системы
    arch-chroot /mnt ./setup_chroot.sh >> ${LOG_FILE} 2>&1 || show_error "${TXT[ERR_CHROOT]}"
    
    # 6. Финальная очистка
    show_progress 10 9 "Final cleanup and logging..."
    rm /mnt/setup_chroot.sh
    
    # Сохранение логов
    cp $LOG_FILE /mnt/var/log/install_script.log
}

# --- MAIN LOOP ---

main() {
    # ASCII Art
    echo -e "${GREEN}"
    cat << "EOF"
   /\
  /  \  rc h   L i n u x
 /    \
/______\  Installer
EOF
    echo -e "${NC}"
    sleep 2

    # Проверка интернета
    if ! ping -c 1 archlinux.org &> /dev/null; then
        show_msg "Internet connection failed. Please connect to the network before running the installer."
        exit 1
    fi

    # Step 1: Язык
    step_language
    
    # Step 1.5: Профиль
    if ! step_profile; then return 0; fi

    # Step 2: Диск
    if ! step_disk; then return 0; fi
    
    # Step 3: Схема
    if ! step_partition_scheme; then return 0; fi

    # NEW Step 3.5: Swap
    if ! step_swap_config; then return 0; fi
    
    # Step 4: GPU (зависит от профиля, теперь с авто-определением)
    if ! step_gpu; then return 0; fi
    
    # Step 5: DE (зависит от профиля)
    if ! step_de; then return 0; fi
    
    # Step 6: Клавиатура
    if ! step_keyboard; then return 0; fi
    
    # Step 7: Система и Юзеры
    if ! step_system_config; then return 0; fi
    
    # Step 8: Timezone & Locale
    if ! step_timezone_locale; then return 0; fi

    # Step 9: Доп. пакеты
    if ! step_packages_extras; then return 0; fi
    
    # Step 10: Загрузчик
    if ! step_bootloader; then return 0; fi
    
    # Финальный обзор
    clear
    cat <<JSON > $CONFIG_FILE
{
  "language": "$LANG_CHOICE",
  "profile": "$SELECTED_PROFILE",
  "disk": "$SELECTED_DISK",
  "scheme": "$PARTITION_SCHEME",
  "gpu": "$GPU_DRIVER",
  "de": "$CHOSEN_DE",
  "layouts": "${KEYMAPS_SELECTED[*]^^}",
  "hostname": "$TARGET_HOSTNAME",
  "user": "$NEW_USER",
  "timezone": "$TIMEZONE",
  "locale": "$LANG_VAR",
  "multilib": "$ENABLE_MULTILIB",
  "extra_pkgs": "$CHOSEN_PACKAGES",
  "aur_helper": "$AUR_HELPER",
  "swap_size_gb": "$SWAP_SIZE_GB",
  "bootloader": "$BOOTLOADER"
}
JSON
    
    dialog --backtitle "${TXT[BACKTITLE]}" --title "Final Summary / Итоговый Обзор" --textbox $CONFIG_FILE 25 75
    
    if show_yesno "${TXT[FINAL_CONFIRM]}"; then
        perform_installation
        show_msg "${TXT[DONE]}"
        if show_yesno "${TXT[DONE]}"; then
            reboot
        fi
    else
        clear
        echo "Installation aborted. Configuration saved to $CONFIG_FILE"
        exit 0
    fi
}

# Обработка прерывания (Ctrl+C)
trap 'echo -e "\n${RED}Script Interrupted.${NC}"; exit 1' INT

# Запуск
main
