#!/bin/bash

#Получаем путь до флэшки
if [ -n "$(lsblk -no NAME,MOUNTPOINT | grep -E "sd..\s+/media")" ]; then
    flash_drive_path=$(echo "$(lsblk -no NAME,MOUNTPOINT | grep -E "sd..\s+/media")" | awk '{print substr($0, index($0,$2))}')
fi

# Проверяем была ли найдена флэшка
if [ -z "$flash_drive_path" ]; then
    echo "Флэш-накопитель не найден."
    exit 1
else
    echo "Найден флэш-накопитель по пути: $flash_drive_path"
fi

# Определение типа файловой системы флэшки
file_system=$(lsblk -f | grep "sdb1" | awk '{print $2}')

echo "Файловая система: $file_system"
echo

# Проверка наличия прав администратора
if sudo -n true 2>/dev/null; then
    admin=1
else
    admin=0
fi

# Определение типа интерфейса флэшки
result=$(lsusb -t | grep "Mass Storage" | awk '{print $11}')
result="${result%M}"
if [ "$result" -eq 480 ]; then
    usb_version="2.0"
else
    usb_version="3.0"
fi

echo "Тип интерфейса: $usb_version"
echo

# Вывод сообщения с предложением выбора
echo "Choose the script:"
echo "1. Make a backup"
echo "2. Delete old backups"
read -p "Write a number: " choice

run_script1() {
    echo "Launching script 1..."

    free_space="Unknown"
    # Получаем объем свободного места
    free_space=$(df -B1 "$flash_drive_path" | awk 'NR==2 {print $4}')

    # Запрашиваем путь к исходной папке для резервного копирования
    read -p "Введите путь к исходной папке: " source_folder

    # Проверяем существование папки
    if [ ! -d "$source_folder" ]; then
        echo "Папка $source_folder не существует. Попробуйте снова."
        exit 1
    fi

    # Проверяем размер файла
    max_file_size_bytes=4294967295
    folder_size=$(du -sb "$source_folder" | awk '{print $1}')
    if [ "$folder_size" -gt "$max_file_size_bytes" ]; then
    if [ "$file_system" == "FAT32" ]; then
            echo "Файл $source_folder превышает максимально допустимый размер для FAT32."
            exit 1
        fi
    fi

    mkdir -p "$flash_drive_path/Backup_$(date +'%Y-%m-%d_%H-%M')"

    #Получаем время начала выполнения скрипта
    start_time=$(date +%s%N)
    # Копируем файлы из исходной папки на флэш-накопитель
    
    cp -r "$source_folder" "$flash_drive_path/Backup_$(date +'%Y-%m-%d_%H-%M')"

    # Получаем время окончания выполнения скрипта
    end_time=$(date +%s%N)
    # Вычисляем разницу во времени выполнения скрипта
    time_diff=$(((end_time - start_time) / 1000000 )) # разница в миллисекундах

    copy_time_seconds=$(echo "scale=3; $time_diff / 1000" | bc)
    # Расчет скорости копирования в мегабайтах в секунду
    speed=$(echo "scale=2; $folder_size / $copy_time_seconds" | bc)
    speed_Mbps=$(echo "scale=2; $speed / (1024 * 1024)" | bc)

    echo "Скорость копирования: $speed_Mbps Мб/с"

    echo "Резервное копирование завершено."
}

run_script2() {
    echo "Launching script 2..."
    # Установка количества дней, после которых папки считаются устаревшими
    days_to_keep=10

    # Определяем текущую дату в формате ГГГГММДД
    current_date=$(date +%Y%m%d)

    # Определяем дату, которая была days_to_keep дней назад
    threshold_date=$(date -d "$days_to_keep days ago" +%Y%m%d)

    while IFS= read -r backup_dir; do
        folder_date=$(echo "$backup_dir" | awk -F '[_]' '{print $2}')
        formatted_date=$(date -d "$folder_date" +%Y%m%d) #Приводим к виду ггггммдд
        if [ "$((formatted_date))" -lt "$((threshold_date))" ]; then
            echo "Deleting folder: $backup_dir"
            rm -rf "$backup_dir"
        fi
    done < <(find "$flash_drive_path" -maxdepth 1 -type d -name "Backup_*")
    exit 0
}

# Проверка выбора пользователя и запуск соответствующего скрипта
if [ "$choice" == "1" ]; then
    run_script1
elif [ "$choice" == "2" ]; then
    run_script2
else
    echo "Incorrect input. Please, choose 1 or 2."
fi

exit 0