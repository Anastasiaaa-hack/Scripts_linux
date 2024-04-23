#!/bin/bash

# Пути к папкам для мониторинга
folders_to_monitor=("/root/1/" "/root/2/")

# Путь к папке для резервных копий
backup_folder="/root/backup"

# Файл для временного хранения состояния файлов
state_file="/root/file_monitor_state.txt"
temp_file="/root/temp_file.txt"

# Очистим файл состояния перед началом мониторинга
echo "" > "$temp_file"

monitor_folders() {
    while true; do
        for folder in "${folders_to_monitor[@]}"; do
            while IFS= read -r -d '' file; do
                process_file "$file"
            done < <(find "$folder" -type f -print0)
        done
        cp -f "$temp_file" "$state_file"
        echo "" > "$temp_file"
        sleep 15
    done
}

process_file() {
    file="$1"
    current_hash=$(md5sum "$file" | awk '{print $1}')
    if [[ -f "$state_file" ]]; then
        found=false
        while IFS='=' read -r hash filename || [[ -n "$hash" ]]; do
            if [[ "$filename" == "$file" ]]; then
                #echo "$file was found"
                found=true
                if [[ "$hash" != "$current_hash" ]]; then
                    echo "File $file has been modified."
                    echo "$current_hash=$file" >> "$temp_file"
                    backup_file "$file"
                else
                    echo "$hash=$file" >> "$temp_file"
                fi
            fi
        done < "$state_file"
        if [[ "$found" == false ]]; then
            #echo "Not found: $file"
            echo "$current_hash=$file" >> "$temp_file"
        fi
    else
        echo "$current_hash=$file" >> "$temp_file"
    fi
}

backup_file() {
    file="$1"
    echo "Backing up file: $file"
    mkdir -p "/root/backup/Backup_$(date +'%Y-%m-%d_%H-%M')"
    cp -R "$file" "/root/backup/Backup_$(date +'%Y-%m-%d_%H-%M')"
    send_email
}

send_email() {
    body="File $file was changed"
    echo $body | ssmtp backup_status@mail.ru
}

monitor_folders