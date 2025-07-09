#!/bin/bash
# Gestor de Archivos Duplicados - Interfaz Gráfica
# Utiliza Zenity para todas las operaciones

###############################################################################
#                     Variables Globales y Configuración                      #
###############################################################################

TARGET_DIR=""
DUPLICATES_FILE=""
BACKUP_DIR="$HOME/DuplicateBackups"
REPORT_DIR="$HOME/DuplicateReports"
TEMP_DIR=$(mktemp -d)

# Crear directorios necesarios
mkdir -p "$BACKUP_DIR" "$REPORT_DIR"

# Colores para mensajes en terminal
COLOR_ERROR="\e[1;31m"
COLOR_SUCCESS="\e[1;32m"
COLOR_RESET="\e[0m"

###############################################################################
#                         Funciones Principales                               #
###############################################################################

select_directory() {
    TARGET_DIR=$(zenity --file-selection \
        --title="Seleccione la carpeta a analizar" \
        --directory \
        --filename="$HOME")
    
    if [ -z "$TARGET_DIR" ]; then
        zenity --error --text="No se seleccionó ningún directorio"
        return 1
    fi
    
    if [ ! -d "$TARGET_DIR" ]; then
        zenity --error --text="El directorio seleccionado no existe"
        return 1
    fi
    
    return 0
}

find_duplicates() {
    if [ -z "$TARGET_DIR" ]; then
        zenity --error --text="Primero seleccione una carpeta"
        return 1
    fi

    # Archivo temporal para resultados
    local tmp_file="$TEMP_DIR/duplicates_$(date +%s).tmp"
    DUPLICATES_FILE="$REPORT_DIR/duplicates_$(date +%Y%m%d_%H%M%S).txt"
    
    (
        # Iniciar progreso
        echo "0"
        echo "# Preparando análisis..."
        
        # Contar archivos totales
        total_files=$(find "$TARGET_DIR" -type f | wc -l)
        processed=0
        
        # Buscar y procesar archivos
        find "$TARGET_DIR" -type f -print0 | while IFS= read -r -d '' file; do
            # Actualizar progreso
            ((processed++))
            percentage=$((processed * 100 / total_files))
            echo "$percentage"
            echo "# Analizando archivo $processed/$total_files: $(basename "$file")"
            
            # Calcular hash y tamaño
            size=$(stat -c %s "$file" 2>/dev/null)
            [ -z "$size" ] && continue
            hash=$(md5sum "$file" | awk '{print $1}')
            [ -z "$hash" ] && continue
            
            # Registrar: hash|tamaño|ruta
            echo "$hash|$size|$file"
        done > "$tmp_file"
        
        # Procesar resultados
        echo "100"
        echo "# Generando reporte final..."
        
        awk -F '|' '{
            key = $1 "," $2
            if (count[key] == 1) {
                print saved[key] >> outfile
            }
            if (count[key] >= 1) {
                print $3 >> outfile
            }
            saved[key] = $3
            count[key]++
        }' outfile="$DUPLICATES_FILE" "$tmp_file"
        
        # Limpiar temporal
        rm -f "$tmp_file"
        
    ) | zenity --progress \
        --title="Analizando duplicados" \
        --text="Preparando análisis..." \
        --percentage=0 \
        --auto-close
    
    # Verificar resultados
    if [ -f "$DUPLICATES_FILE" ] && [ -s "$DUPLICATES_FILE" ]; then
        dup_count=$(wc -l < "$DUPLICATES_FILE")
        zenity --info --title="Análisis completado" \
            --text="Se encontraron $dup_count archivos duplicados\n\nResultados guardados en:\n$DUPLICATES_FILE"
        return 0
    else
        zenity --info --title="Análisis completado" \
            --text="No se encontraron archivos duplicados"
        DUPLICATES_FILE=""
        return 1
    fi
}

list_duplicates() {
    if [ -z "$DUPLICATES_FILE" ] || [ ! -f "$DUPLICATES_FILE" ]; then
        zenity --error --text="Primero debe analizar los duplicados"
        return 1
    fi
    
    zenity --text-info \
        --title="Archivos duplicados" \
        --filename="$DUPLICATES_FILE" \
        --width=800 \
        --height=600
}

delete_selected_duplicates() {
    if [ -z "$DUPLICATES_FILE" ] || [ ! -f "$DUPLICATES_FILE" ]; then
        zenity --error --text="Primero debe analizar los duplicados"
        return 1
    fi
    
    # Crear lista de selección
    mapfile -t files < "$DUPLICATES_FILE"
    list_items=()
    for file in "${files[@]}"; do
        list_items+=(FALSE "$file")
    done
    
    # Mostrar diálogo de selección
    selected=$(zenity --list \
        --title="Seleccionar archivos para eliminar" \
        --text="Seleccione los archivos duplicados que desea eliminar:" \
        --checklist \
        --column="Eliminar" \
        --column="Archivo" \
        --width=800 \
        --height=600 \
        "${list_items[@]}")
    
    if [ -z "$selected" ]; then
        zenity --info --text="No se seleccionaron archivos para eliminar"
        return 0
    fi
    
    # Confirmar eliminación
    count=$(echo "$selected" | wc -l)
    zenity --question \
        --title="Confirmar eliminación" \
        --text="¿Está seguro que desea eliminar $count archivos?\n\nEsta acción creará una copia de seguridad" \
        --width=400 || return 0
    
    # Crear copia de seguridad
    local backup_dir="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Mover archivos seleccionados
    moved=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Crear estructura de directorios en backup
            local rel_path="${file#$TARGET_DIR}"
            local backup_path="$backup_dir$rel_path"
            mkdir -p "$(dirname "$backup_path")"
            
            # Mover el archivo
            mv -- "$file" "$backup_path" && ((moved++))
        fi
    done <<< "$selected"
    
    zenity --info --title="Eliminación completada" \
        --text="Se movieron $moved archivos a:\n$backup_dir"
}

delete_all_duplicates() {
    if [ -z "$DUPLICATES_FILE" ] || [ ! -f "$DUPLICATES_FILE" ]; then
        zenity --error --text="Primero debe analizar los duplicados"
        return 1
    fi
    
    # Contar archivos
    total_files=$(wc -l < "$DUPLICATES_FILE")
    
    # Confirmar eliminación
    zenity --question \
        --title="Confirmar eliminación total" \
        --text="¿Está seguro que desea eliminar TODOS los $total_files archivos duplicados?\n\nEsta acción creará una copia de seguridad" \
        --width=400 || return 0
    
    # Crear copia de seguridad
    local backup_dir="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Mover todos los archivos
    moved=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Crear estructura de directorios en backup
            local rel_path="${file#$TARGET_DIR}"
            local backup_path="$backup_dir$rel_path"
            mkdir -p "$(dirname "$backup_path")"
            
            # Mover el archivo
            mv -- "$file" "$backup_path" && ((moved++))
        fi
    done < "$DUPLICATES_FILE"
    
    zenity --info --title="Eliminación completada" \
        --text="Se movieron $moved archivos a:\n$backup_dir"
    
    # Limpiar archivo de duplicados
    DUPLICATES_FILE=""
}

clean_all() {
    if [ -z "$TARGET_DIR" ]; then
        zenity --error --text="Primero seleccione una carpeta"
        return 1
    fi
    
    # Confirmar limpieza
    zenity --question \
        --title="Confirmar limpieza completa" \
        --text="¿Está seguro que desea eliminar TODOS los archivos duplicados en la carpeta?\n\nEsta acción creará una copia de seguridad" \
        --width=400 || return 0
    
    # Crear copia de seguridad
    local backup_dir="$BACKUP_DIR/full_clean_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Contadores
    total_files=0
    moved_files=0
    
    (
        echo "0"
        echo "# Preparando limpieza completa..."
        
        # Contar archivos totales
        total_files=$(find "$TARGET_DIR" -type f | wc -l)
        processed=0
        
        # Buscar y mover duplicados
        declare -A seen
        find "$TARGET_DIR" -type f -print0 | while IFS= read -r -d '' file; do
            # Actualizar progreso
            ((processed++))
            percentage=$((processed * 100 / total_files))
            echo "$percentage"
            echo "# Procesando archivo $processed/$total_files: $(basename "$file")"
            
            # Calcular hash
            hash=$(md5sum "$file" | awk '{print $1}')
            [ -z "$hash" ] && continue
            
            # Verificar si ya hemos visto este hash
            if [[ -n "${seen[$hash]}" ]]; then
                # Mover a backup
                local rel_path="${file#$TARGET_DIR}"
                local backup_path="$backup_dir$rel_path"
                mkdir -p "$(dirname "$backup_path")"
                mv -- "$file" "$backup_path" && ((moved_files++))
            else
                seen["$hash"]=1
            fi
        done
        
        echo "100"
        echo "# Limpieza completada!"
        
    ) | zenity --progress \
        --title="Limpiando duplicados" \
        --text="Preparando limpieza..." \
        --percentage=0 \
        --auto-close
    
    zenity --info --title="Limpieza completada" \
        --text="Se movieron $moved_files archivos duplicados a:\n$backup_dir"
}

generate_report() {
    if [ -z "$DUPLICATES_FILE" ] || [ ! -f "$DUPLICATES_FILE" ]; then
        zenity --error --text="Primero debe analizar los duplicados"
        return 1
    fi
    
    local report_file="$REPORT_DIR/report_$(date +%Y%m%d_%H%M%S).html"
    
    # Crear reporte HTML
    cat <<HTML > "$report_file"
<!DOCTYPE html>
<html>
<head>
    <title>Reporte de Duplicados</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        .group { background-color: #f9f9f9; border: 1px solid #ddd; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
        .file-list { margin-left: 20px; }
        .file-item { margin: 5px 0; }
        .original { font-weight: bold; color: #27ae60; }
        .duplicate { color: #e74c3c; }
    </style>
</head>
<body>
    <h1>Reporte de Archivos Duplicados</h1>
    <p><strong>Directorio analizado:</strong> $TARGET_DIR</p>
    <p><strong>Fecha del análisis:</strong> $(date)</p>
    <hr>
HTML

    # Procesar duplicados
    awk '
    BEGIN { group = 0 }
    {
        if (!($0 in seen)) {
            group++
            print "<div class=\"group\">"
            print "<h2>Grupo de duplicados #" group "</h2>"
            print "<div class=\"file-list\">"
            print "<div class=\"file-item original\">" $0 "</div>"
            print "</div></div>"
        }
        seen[$0] = 1
    }' "$DUPLICATES_FILE" >> "$report_file"

    echo "</body></html>" >> "$report_file"
    
    # Abrir el reporte
    xdg-open "$report_file" >/dev/null 2>&1 &
    
    zenity --info --title="Reporte generado" \
        --text="El reporte se ha generado en:\n$report_file"
}

###############################################################################
#                         Menús Gráficos                                      #
###############################################################################

show_main_menu() {
    while true; do
        choice=$(zenity --list \
            --title="Gestor de Archivos Duplicados" \
            --text="Seleccione una opción:" \
            --column="Opción" --column="Descripción" \
            --width=600 --height=300 \
            "1" "Buscar carpeta" \
            "2" "Analizar duplicados" \
            "3" "Eliminar archivos duplicados" \
            "4" "Limpiar todo" \
            "5" "Salir")
        
        if [ -z "$choice" ]; then
            exit 0
        fi
        
        case $choice in
            1) select_directory ;;
            2) find_duplicates ;;
            3) show_delete_menu ;;
            4) clean_all ;;
            5) exit 0 ;;
        esac
    done
}

show_delete_menu() {
    while true; do
        choice=$(zenity --list \
            --title="Gestión de Duplicados" \
            --text="Seleccione una acción:" \
            --column="Opción" --column="Descripción" \
            --width=600 --height=300 \
            "1" "Listar archivos duplicados" \
            "2" "Seleccionar archivos para eliminar" \
            "3" "Eliminar todos los duplicados" \
            "4" "Generar reporte completo" \
            "5" "Volver al menú principal")
        
        if [ -z "$choice" ]; then
            return
        fi
        
        case $choice in
            1) list_duplicates ;;
            2) delete_selected_duplicates ;;
            3) delete_all_duplicates ;;
            4) generate_report ;;
            5) return ;;
        esac
    done
}

###############################################################################
#                         Inicio del Programa                                 #
###############################################################################

# Verificar dependencias
if ! command -v zenity &> /dev/null; then
    echo -e "${COLOR_ERROR}Error: Zenity no está instalado.${COLOR_RESET}"
    echo "Instale Zenity para usar la interfaz gráfica:"
    echo "  sudo apt install zenity"
    exit 1
fi

# Iniciar con el menú principal
show_main_menu

# Limpiar al salir
rm -rf "$TEMP_DIR"
