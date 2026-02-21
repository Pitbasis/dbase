#!/bin/sh

DB_USER="postgres"
SQL="psql"
#-----------------------------------------------------------------------
#if User ---------------
RootMod="sudo"
RootMetod="-u"
#or root (SuperUser) ---
#RootMod=""
#RootMetod=""

ID_Search() {
 if [ -n "$3" ]; then
  $RootMod $RootMetod $DB_USER $SQL -d $1 -x -c "SELECT * FROM \"$2\" WHERE id = '$3';"
 else
  echo -n "  ID:"
  read search_id
  $RootMod $RootMetod $DB_USER $SQL -d $1 -x -c "SELECT * FROM \"$2\" WHERE id = '$search_id';"
 fi
}
#Over ID shearch Element -------------------------
Search_Element() {
    local db="$1"
    local tbl="$2"
    cols=$($RootMod $RootMetod $DB_USER $SQL -d "$db" -t -A -c "SELECT column_name FROM information_schema.columns WHERE table_name = '$tbl' ORDER BY ordinal_position;")
    echo "Available columns:"
    echo "$cols" | tr '\n' ' '
    echo ""
    echo -n "Search by column: "
    read search_col
    check_col=$(echo "$cols" | grep -w "$search_col")
    if [ -z "$check_col" ]; then
        echo "Error: Column '$search_col' not found."
        return 1
    fi
    echo -n "Enter exact value: "
    read search_val
    if [ -z "$search_val" ]; then
        echo "Error: Value cannot be empty."
        return 1
    fi
    echo "--- Results ---"
    $RootMod $RootMetod $DB_USER $SQL -d "$db" -c "SELECT * FROM \"$tbl\" WHERE \"$search_col\"::text = '$search_val';"
}
#Over Search_Element     ------------------------
Drop_Element(){
 if [ -n "$3" ]; then
  exists=$($RootMod $RootMetod $DB_USER $SQL -d "$1" -t -A -c "SELECT count(*) FROM \"$2\" WHERE id = '$3';")
  if [ "$exists" -eq 0 ]; then
     echo "Error: Element with ID:$search_id NOT FOUND in table \"$2\"."
     return 1
  fi
  echo -n "Did you really decide to delete the element with this ID:$3? [y/n] "
  read yn
  if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
     $RootMod $RootMetod $DB_USER $SQL -d $1 -c "DELETE FROM \"$2\" WHERE id = '$3';"
     echo "This element was deleted. ID:$3"
     echo "Bye element ID:$3 :{ "
  else
     echo "This element was not deleted. ID:[$3]"
  fi
 else 
  echo -n "  ID:"
  read search_id
  if [ -z "$search_id" ]; then
      echo "Error: ID cannot be empty!"
      return 1
  fi
  exists=$($RootMod $RootMetod $DB_USER $SQL -d "$1" -t -A -c "SELECT count(*) FROM \"$2\" WHERE id = '$search_id';")
  if [ "$exists" -eq 0 ]; then
     echo "Error: Element with ID:$search_id NOT FOUND in table \"$2\"."
     return 1
  fi
  echo -n "Did you really decide to delete the element with this ID:$search_id? [y/n] "
  read yN
  if [ "$yN" = "y" ] || [ "$yN" = "Y" ]; then 
     $RootMod $RootMetod $DB_USER $SQL -d $1 -c "DELETE FROM \"$2\" WHERE id = '$search_id';"
     echo "This element was deleted. ID:$search_id "
     echo "Bye element ID:$search_id :{ "
  else 
     echo "This element was not deleted. ID:$search_id "
  fi
 fi
}
#Over Drop Elemnt        ------------------------
Edit_Element() {
    local db="$1"
    local tbl="$2"
    local target_id="$3"
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    current_data=$($RootMod $RootMetod $DB_USER $SQL -d "$db" -tUpdate -A -F'|' -c "SELECT * FROM \"$tbl\" WHERE id = '$target_id';")
    if [ -z "$current_data" ]; then
        echo "|"
        echo "| Error: Element with ID:$target_id not found."
        echo "|______________________________________________________|"
        echo "|  Please check the element ID or create a new element |"
        echo "|______________________________________________________|"
        return 1
    else
        echo "Database check completed successfully"
        echo "_____________________________________"
    fi
    cols=$($RootMod $RootMetod $DB_USER $SQL -d "$db" -t -A -c "SELECT column_name FROM information_schema.columns WHERE table_name = '$tbl' ORDER BY ordinal_position;")
    echo "--- Editing ID: $target_id ---"
    echo "Tip: Type \$time to insert current timestamp"
    update_query=""
    i=1
    for col in $cols; do
        current_val=$(echo "$current_data" | cut -d'|' -f$i)
        echo -n "$col [$current_val]: "
        read new_val
        if [ "$new_val" = "\$time" ]; then
            new_val="$current_time"
        fi
        if [ -n "$new_val" ]; then
            if [ "$col" = "id" ]; then
                check_id=$(sudo -u $DB_USER $SQL -d "$db" -t -A -c "SELECT count(*) FROM \"$tbl\" WHERE id = '$new_val';")
                if [ "$check_id" -ne 0 ]; then
                    echo "Error: ID $new_val already exists! Skipping ID change."
                    new_val=""
                fi
            fi  
            if [ -n "$new_val" ]; then
                [ -n "$update_query" ] && update_query="$update_query, "
                update_query="${update_query}\"$col\" = '$new_val'"
            fi
        fi
        i=$((i+1))
    done
    if [ -n "$update_query" ]; then
        $RootMod $RootMetod $DB_USER $SQL -d "$db" -c "UPDATE \"$tbl\" SET $update_query WHERE id = '$target_id';"
        echo "Done. Updated at: $current_time"
    else
        echo "No changes."
    fi
}
#Over Edit Element       -------------------------------------------
Monitorig_DB() {
sockstat -4 | grep postgres
nc -z localhost 5432 && echo OK
}
#Over monitoring DB      -----------------------------------------
Create_Element() {
  $RootMod $RootMetod $DB_USER $SQL -d $1 -c "\d $2"
  columns_raw=$(sudo -u $DB_USER $SQL -d $1 -t -A -c "
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_name = '$2' 
    AND column_default IS NULL 
    ORDER BY ordinal_position;")

   col_names=""
   col_values=""
   for col in $columns_raw; do
     echo -n "Enter a value in the field-> [$col]: "
     read user_input
     #Time
     if [ "$user_input" == "\$time" ]; then
        formatted_value="now()"
     elif [ -z "$user_input" ]; then
        formatted_value="NULL"
     else
        formatted_value="'$user_input'"
     fi
     #All text 
     if [ -z "$col_names" ]; then
        col_names="\"$col\""
        col_values="$formatted_value"
     else
        col_names="$col_names, \"$col\""
        col_values="$col_values, $formatted_value"
     fi
  done
  final_sql="INSERT INTO $2 ($col_names) VALUES ($col_values);"
  echo "---"
  echo "Executing the request...: $final_sql"
  $RootMod $RootMetod $DB_USER $SQL -d $1 -c "$final_sql"
}
#Over Create_Element ------------------------------------------
GET_Table(){
	 echo "--- DATA IN TABLE: $2 (Database: $1) ---"
     $RootMod $RootMetod $DB_USER $SQL -d $1 -c "SELECT * FROM $2;"
}
#Over GET_TABEL -----------------------------------------------
GET_Structur_Table(){
     echo "--- STRUCTURE OF TABLE: $2 (Database: $1) ---"
     $RootMod $RootMetod $DB_USER $SQL -d $1 -c "\d $2"
}
#Over GET Structru Table --------------------------------------
Lmit_Element() {
         if [ -z "$4" ]; then
           echo "Error -->" 
           echo ""
           echo "  [name] [Table] -l --> [Limit] <--   you don't write Limit"
           echo ""
           echo ""
           echo "  [name] [Table]                      Show tables in Database Table"
           echo "  -------------OR------------"
           echo "  [name] [Table] -l [Limit]           Show tables in Database Table Element-Limit"
           echo ""
           echo "dbbasis -h or help :D "  
         else
           echo "--- DATA IN TABLE: $2 (Limit: $4 )(Database: $1) ---"
           $RootMod $RootMetod $DB_USER psql -d $1 -c "SELECT * FROM $2 LIMIT $4;"
         fi
}
#Over Limet Element  -----------------------------------------
Create_DataBase(){
	if [ -z "$2" ]; then
        echo "Error not have NAME_DB -> dbbasis [-c] [NAME_DB] --> CREATE DATABASE "
        echo ""
        echo "help... -> dbbasis [help] or [-h]"
    else
        echo "$2 Creating ... "
        $RootMod $RootMetod $DB_USER $SQL -c "CREATE DATABASE $2;"
        #data dase publick
        $RootMod $RootMetod $DB_USER $SQL -d $2 -c "GRANT ALL ON SCHEMA public TO public;"
    fi
}
#Over Create_DataBase ----------------------------------------
Renam_Database() {
        echo "Renaming database $2 to $3..."
        $RootMod $RootMetod $DB_USER $SQL -c "ALTER DATABASE $2 RENAME TO $3;"
}
#Over Renam_Database   ---------------------------------------
Restore_DataBase(){
             FILE_PATH="$3"
             if [ -z "$FILE_PATH" ]; then
                 echo "Error: Please specify the .sql file."
                 echo "Usage: db $1 -restore path/to/file.sql"
             elif [ ! -f "$FILE_PATH" ]; then
                 echo "Error: File '$FILE_PATH' not found!"
             else
                 printf "WARNING: This will overwrite data in database '$1'. Continue? (y/n): "
                 read confirm
                 if [ "$confirm" = "y" ]; then
                     echo "Restoring database $1 from $FILE_PATH..."
                     $RootMod $RootMetod $DB_USER $SQL -d $1 < "$FILE_PATH"
                     if [ $? -eq 0 ]; then
                         echo " SUCCESS: Database $1 has been restored."
                     else
                         echo " ERROR: Restore failed!"
                     fi
                 else
                     echo "Operation cancelled."
                 fi
             fi
}
# Self-Installation Logic ----------------------------------------------
	TARGET="/usr/local/bin/dbbasis"

	if [ "$0" != "$TARGET" ]; then
    echo "Installing dbbasis to /usr/local/bin..."
    sudo cp "$0" "$TARGET"
    sudo chmod +x "$TARGET"
    echo "Installation complete. You can now use 'dbbasis' from anywhere."
    # Optional: exit here so it doesn't run the rest of the script during install
    exit 0
#Over Restore_DataBase  --------------------------------------
Clear_Table(){
	 printf "Are you sure you want to Clearing Table $2? (y/n): "
     read confirm
     if [ "$confirm" = "y" ]; then
         echo "Clearing all data from table $2..."
         $RootMod $RootMetod $DB_USER $SQL -d $1 -c "TRUNCATE TABLE $2 CASCADE;"
     else
         echo "Operation cancelled."
     fi
}
Test_DB() {
  DB_EXISTS=$(sudo -u "$DB_USER" $SQL -tAc \
  "SELECT 1 FROM pg_database WHERE datname='$2';")
  if [ "$DB_EXISTS" = "1" ] || [ "$1" = "-clear" ] || [ "$1" = "-CE" ] || [ "$1" = "-L" ] || [ "$1" = "GET" ] || [ "$1" = "-c" ] || [ "$1" = "-d" ] || [ "$1" = "-id" ] || [ "$1" = "-s" ] || [ "$1" = "-e" ] || [ "$1"  = "-dt" ] || [ "$1" = "-rt" ] || [ "$1" = "-r" ] || [ "$1" = "--Searche" ] || [ "$1" = "*Ct" ]; then
    if [ "$1" = "-clear" ]; then
       DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
       "SELECT 1 FROM pg_database WHERE datname='$2';")
       if [ "$DB_EXISTS_RENAME" != "1" ]; then 
        TABLE_EXISTS_GET_N=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
        "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public'
        AND table_name = '$3';" "$2")
        if [ "$TABLE_EXISTS_GET_N" != "1" ]; then
           echo "| Error ---->"                             
           echo "|"
           echo "| dbbasis [$2] [$3]"
           echo "|         OK        ERROR      NONE"
           echo "|___________________________________|"
           echo "| You specified a non-existent table|"
           echo "| Please check the table.           |"
           echo "|___________________________________|"
           exit 1
        else 
          echo "Database check completed successfully"
          echo "_____________________________________"
        fi
       else
         echo "|                                                                                "
         echo "| Error DB name [$3]                                                             "
         echo "|________________________________________________________________________________|"
         echo "|  A database with the specified name already exists. Please select another name |"
         echo "|  or rename the existing database                                               |"
         echo "|________________________________________________________________________________|"
         exit 1
       fi
    elif [ "$1" = "*Ct" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" != "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  -c [$3] '[Cols]'"
              echo "|         OK         ERROR"
              echo "|_______________________________________________________|"
              echo "| A table with this name already existsts.              |"
              echo "| Please choose another name or rename the existing one.|"
              echo "|_______________________________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] -c [$3] '[Cols]'"
           echo "|         ERROR      NONE     NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "-CE" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" != "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] -c"
              echo "|         OK      ERROR"
              echo "|_______________________________________________________|"
              echo "| A table with this name already existsts.              |"
              echo "| Please choose another name or rename the existing one.|"
              echo "|_______________________________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] -c"
           echo "|         ERROR      NONE  "
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "-s" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] -s"
              echo "|         OK      ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] -s"
           echo "|         ERROR     NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "-L" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] -l [Limit]"
              echo "|         OK      ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] -l [limit]"
           echo "|         ERROR     NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "GET" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] "
              echo "|         OK     ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] "
           echo "|         ERROR     NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "--Searche" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] --Searche"
              echo "|         OK      ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] --Searche"
           echo "|         ERROR    NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "-e" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] -e [id] "
              echo "|         OK      ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] -e [id] "
           echo "|         ERROR    NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "-id" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] -id [id] "
              echo "|         OK      ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] -id [id] "
           echo "|         ERROR    NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "-d" ]; then
         DB_EXISTS_RENAME=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
         "SELECT 1 FROM pg_database WHERE datname='$2';")
         if [ "$DB_EXISTS_RENAME" = "1" ]; then 
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2]  [$3] -d [id] "
              echo "|         OK      ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
         else
           echo "| Error ------>                                                                  "
           echo "|"
           echo "|  dbbasis [$2] [$3] -d [id] "
           echo "|         ERROR    NONE"
           echo "|__________________________________________|"
           echo "|  You specified a non-existent database.  |"
           echo "|  Please check the database.              |"
           echo "|__________________________________________|"
           exit 1
         fi 
    elif [ "$1" = "-c" ]; then
       DB_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
       "SELECT 1 FROM pg_database WHERE datname='$2';")
       if [ "$DB_EXISTS_GET" != "1" ]; then
         echo "Database check completed successfully"
         echo "_____________________________________"
       else 
         echo "|                                                                                "
         echo "| Error DB name [$2]                                                             "
         echo "|________________________________________________________________________________|"
         echo "|  A database with the specified name already exists. Please select another name |"
         echo "|  or rename the existing database                                               |"
         echo "|________________________________________________________________________________|"
         exit 1
       fi
    elif [ "$1" = "-dt" ]; then 
       DB_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
       "SELECT 1 FROM pg_database WHERE datname='$2';")
       if [ "$DB_EXISTS_GET" = "1" ]; then
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public'
          AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
          else 
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2] -dt [$3]"
              echo "|         OK           ERROR"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"
              exit 1
          fi
       else
             echo "| Error ---->"
             echo "|"
             echo "| dbbasis [$2] -dt [$3]"
             echo "|        ERROR         ERROR"
             echo "|_______________________________________|"
             echo "| You specified a non-existent database.|"
             echo "| Please check the database.            |"
             echo "|_______________________________________|"
             exit 1
       fi	 
    elif [ "$1" = "-rt" ]; then
      if [ -n "$3" ] && [ -n "$4" ]; then  
       DB_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
       "SELECT 1 FROM pg_database WHERE datname='$2';")
       if [ "$DB_EXISTS_GET" = "1" ]; then
          TABLE_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
          "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public'
          AND table_name = '$3';" "$2")
          if [ "$TABLE_EXISTS_GET" = "1" ]; then
             TABLE_EXISTS_GET_N=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
             "SELECT 1 FROM pg_tables WHERE schemaname='public'
             AND table_name = '$4';" "$2")
             if [ "$TABLE_EXISTS_GET_N" != "1" ]; then 
                 echo "Database check completed successfully"
                 echo "_____________________________________"
             else
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2] -rt [$3] [$4]"
              echo "|         OK        OK      ERROR"
              echo "|_______________________________________________________|"
              echo "| A table with this name already existsts.              |"
              echo "| Please choose another name or rename the existing one.|"
              echo "|_______________________________________________________|"
              exit 1
             fi 
          else
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis [$2] -rt [$3] [$4]"
              echo "|         OK        ERROR      NONE"
              echo "|____________________________________|"
              echo "| You specified a non-existent table.|"
              echo "| Please check the table.            |"
              echo "|____________________________________|"        
              exit 1
          fi
       else
             echo "| Error ---->"
             echo "|"
             echo "| dbbasis [$2] -rt [$3] [$4]"
             echo "|        ERROR         NONE     NONE"
             echo "|_______________________________________|"
             echo "| You specified a non-existent database.|"
             echo "| Please check the database.            |"
             echo "|_______________________________________|"
             exit 1
       fi 
      else 
             echo "| Error ---->"
             echo "|"
             echo "| dbbasis [$2] -rt [$3] [$4]"
             echo "|        NONE       NONE     NONE"
             echo "|_________________________________________|"
             echo "|                                         |"
             echo "| Please check the values after -rt [] [] |"
             echo "|_________________________________________|"
             exit 1
      fi
    elif [ "$1" = "-r" ]; then 
      if [ -n  "$2" ] && [ -n "$3" ]; then 
        DB_EXISTS_GET=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$2';")
        if [ "$DB_EXISTS_GET" = "1" ]; then
           DB_EXISTS_TEST=$($RootMod $RootMetod "$DB_USER" $SQL -tAc \
           "SELECT 1 FROM pg_database WHERE datname='$3';")
           if [ "$DB_EXISTS_TEST" != "1" ]; then
              echo "Database check completed successfully"
              echo "_____________________________________"
           else
              echo "| Error ---->"
              echo "|"
              echo "| dbbasis -r [$2] [$3]"
              echo "|           OK      ERROR"
              echo "|_______________________________________________________|"
              echo "| A database with this name already existsts.           |"
              echo "| Please choose another name or rename the existing one.|"
              echo "|_______________________________________________________|"
              exit 1 
           fi            
        else
           echo "| Error ---->"
           echo "|"
           echo "| dbbasis -r [$2] [$3]"
           echo "|           ERROR  NONE"
           echo "|_______________________________________|"
           echo "| You specified a non-existent database.|"
           echo "| Please check the database.            |"
           echo "|_______________________________________|"
           exit 1
        fi
      else
        echo "| Error ---->"
        echo "|"
        echo "| dbbasis -r [$3] [$4]"
        echo "|          NONE  NONE"
        echo "|_________________________________________|"
        echo "|                                         |"
        echo "| Please check the values after  -r [] [] |"
        echo "|_________________________________________|"
        exit 1 
      fi
    else
       echo "Database check completed successfully"
       echo "_____________________________________"
    fi 
  else  
    echo "Database NOT found [$2]" 
    exit 1
  fi
}
#Over test DB ------------------------------------------------------------------
case "$1" in
    --sql)
       echo " ALL .sql file"
       realpath *.sql
       ;;
    -a)
        echo " All DATABASES -->"        
        $RootMod $RootMetod $DB_USER $SQL -l
        ;;
    -c)
        Test_DB "$1" "$2"
        Create_DataBase "$1" "$2"
        ;;
    -d)
        Test_DB "$1" "$2"
        printf "Are you sure you want to DELETE database $2? (y/n): "
        read confirm
        if [ "$confirm" = "y" ]; then
            $RootMod $RootMetod $DB_USER $SQL -c "DROP DATABASE $2;"
            echo "Database deleted."
            echo "Bye $2 :("
        else
            echo "Operation cancelled."
        fi
        ;;
    -v)
        echo ""
        echo "PostgreSQL info"
        $SQL -V
        echo "pkg info "
        pkg info | grep postgres
        echo " "
        echo " "
        Monitorig_DB 
        ;;
    -r)
        Test_DB "$1" "$2" "$3"
        Renam_Database "$1" "$2" "$3"
        ;;
    -h|help)
        echo "Usage:"
        echo "  -h or help                   help"
        echo "  -d [name]                    Delete (Drop) Database"
        echo "  [name] -dt [Table]           Delete (Drop) Table "
        echo "  -r [old] [new]               Rename Database"
        echo "  [name] -rt [old] [new]       Rename Table "
        echo "  -c [name]                    Create a new Database"
        echo "  -v                           Show version info"
        echo "  -a                           Show all Databases"
        echo "  [name]                       Show tables in Database"
	    echo "  [name] -l [Limit]            Show tables in Database Table-Limit "
	    echo "  [name] [Table]               Show tables in Database Table "
        echo "  [name] [Table] -c            Create Element"
	    echo "  [name] [Table] --Searche     Searche Element  "
	    echo "  [name] [Table] -id           Searche Element in id "
	    echo "  [name] [Table] -d [id]       Delete (Drop) Element "
	    echo "  [name] [Table] -e [id]       Edit Element"
        echo "  [name] [Table] -l [Limit]    Show tables in Database Table Elemnt-Limit"
        echo "  [name] -c [Table] '[Cols]'   Create a new Table (dbbasis Databases -c Table 'id serial PRIMARY KEY, name varchar(255), email text')"
        echo "  [name] [Table] -s            Structure of Table "
        echo "  [name] [Table] -clear        Clear in Table"
        echo "  [name] -dump                 Save your Database .sql "
        echo "  [name] -restore [file.sql]   Restore Database from .sql file "
        echo "  --sql                        Show all .sql file"
        ;;
    *)
        if [ -z "$1" ]; then
            echo "ERROR. <-> dbbasis [NAME_DATABASE] -> GET DATABASE"
            echo ""
            echo "help... -> dbbasis [help] or [-h]"
        elif [ -z "$2" ]; then
             Test_DB "*" "$1"
             echo " TABLES IN DATABASE $1 -->"
             $RootMod $RootMetod $DB_USER $SQL -d $1 -c "\dt"
        elif [ "$2" = "-l" ]; then 
             Test_DB "*l" "$1"
             echo " TABLES IN DATABASE $1 (Limit: $3) -->"
             $RootMod $RootMetod $DB_USER $SQL -d $1 -c "
             SELECT 
                n.nspname as \"Schema\",
                c.relname as \"Name\",
                CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' END as \"Type\",
                pg_catalog.pg_get_userbyid(c.relowner) as \"Owner\"
             FROM pg_catalog.pg_class c
                  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
             WHERE c.relkind = 'r' 
                  AND n.nspname = 'public'
             ORDER BY c.relname
             LIMIT $3;"
            # OR ->
            # $RootMod $RootMetod $DB_USER $SQL -d $1 -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' LIMIT $3;"
        elif [ "$2" = "-c" ]; then 
             Test_DB "*Ct" "$1" "$3"
             echo "creat a new teble $3"
             echo ""
             echo "$4"
             echo ""
             $RootMod $RootMetod $DB_USER $SQL -d $1 -c "CREATE TABLE $3 ($4);"
        elif [ "$2" = "-dt" ]; then
	         Test_DB "-dt" "$1" "$3"
             printf "Are you sure you want to DELETE Table $3? (y/n): "
             read confirm
             if [ "$confirm" = "y" ]; then
               echo "Deleting table $3 from $1..."
               $RootMod $RootMetod $DB_USER $SQL -d $1 -c "DROP TABLE $3;"
               echo "Bye $3 :("
             else
               echo "Operation cancelled."
             fi
        elif [ "$2" = "-dump" ]; then
             Test_DB "$2" "$1"
             FILENAME="${1}_backup_$(date +%Y%m%d_%H%M%S).sql"
             echo "Starting backup for database: $1..."
             echo "Destination: $FILENAME"
             $RootMod $RootMetod $DB_USER pg_dump -h /tmp $1 > "$FILENAME"
             if [ $? -eq 0 ]; then
               echo "------------------------------------------"
               echo "SUCCESS: Backup created successfully!"
               echo "File size: $(du -sh $FILENAME | cut -f1)"
               echo "------------------------------------------"
             else
               echo "ERROR: Backup failed!"
               rm -f "$FILENAME" 
             fi
        elif [ "$2" = "-rt" ]; then
              Test_DB "-rt" "$1" "$3" "$4" 
              echo "Renaming table $3 to $4 in database $1..."
              $RootMod $RootMetod $DB_USER $SQL -d $1 -c "ALTER TABLE $3 RENAME TO $4;"
        elif [ "$3" = "-clear" ] && [ "$2" != "-dt" ]  && [ "$2" != "-l" ] && [ "$2" != "-c" ]; then
             Test_DB "-clear" "$1" "$2"
             Clear_Table "$1" "$2"
        elif [ "$2" = "-restore" ]; then
             Test_DB "$2" "$1"
             Restore_DataBase "$1" "$2" "$3"
        elif [ -n "$2" ] && [ "$2" != "-l" ] && [ "$2" != "-c" ] && [ "$3" = "-s" ]; then
             Test_DB "$3" "$1" "$2"
             GET_Structur_Table "$1" "$2"
        elif [ -z "$3" ] && [ "$2" != "-l" ] && [ "$2" != "-c" ]; then
             Test_DB "GET" "$1" "$2" 
             GET_Table "$1" "$2"
        elif [ "$3" = "-l" ]; then 
             Test_DB "-L" "$1" "$2" "$4"
             Lmit_Element "$1" "$2" "*" "$4"
        elif [ "$3" = "--Searche" ]; then
             Test_DB "$3" "$1" "$2"
             Search_Element "$1" "$2"
        elif [ "$3" = "-e" ] && [ -n "$2" ]; then
             Test_DB "$3" "$1" "$2"
             Edit_Element "$1" "$2" "$4" 
        elif [ "$3" = "-id" ] && [ -n "$2" ]; then
             Test_DB "$3" "$1" "$2"
             ID_Search "$1" "$2" "$4"
        elif [ "$3" = "-d" ] && [ -n "$2" ]; then
             Test_DB "$3" "$1" "$2"
             Drop_Element "$1" "$2" "$4"
        elif [ "$3" = "-c" ] && [ -n "$2" ]; then
             Test_DB "-CE" "$1" "$2"
             Create_Element "$1" "$2"
             # dbbasis "$1" " $2"
        fi
        
        ;;
esac



