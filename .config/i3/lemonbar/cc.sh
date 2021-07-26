#!/usr/bin/bash

. $(dirname $0)/config
. $(dirname $0)/colors

foc_wsp_fore=${color166}
curret_wsp=
update=true
while true
do
    update=false
    log=$(i3-msg -t subscribe '[ "workspace" ]' 2>/dev/null | jq -r ".change")
    update=true
done &
Clock() {
        DATETIME=$(date "+%a %b %d ${sep_l_left} ${icon_clock} %H:%M")

        echo -n "${icon_calendar} $DATETIME"
}

Nvidia(){
  tmp=$(cat /proc/acpi/bbswitch 2>/dev/null | cut -d" " -f2)
  if [[ $tmp == "ON" ]]
  then
    info=${sep_l_left}" "${icon_nvd}" "$( nvidia-settings -q GPUUtilization -t 2> /dev/null | awk '{gsub(/[A-Z]/,""); gsub(/[a-z]/,""); gsub(",", ""); gsub("=", ""); {for(n=1;n<=NF;n++){$n=$n"% | "}}print}' )$(nvidia-settings -q ThermalSensorReading -t 2> /dev/null)"°C"
    echo -n $info
  fi

}

GetNames(){
    num=$(($1-1 ))
    shift
    classes=$(echo $*)
    default=$(jq -r --arg n $num '.[$n | tonumber].default' $(dirname $0)/wspnames.json)
    newname=$default
    for class in $classes
    do
        if [[ $newname == $default ]]
        then
            newname=$(jq -r --arg n $num --arg c $class '.[$n | tonumber] | if(has($c)) then .[$c] else .default end' $(dirname $0)/wspnames.json)
        fi
    done
    echo $newname
}

Workspaces(){
    if [ "$update" = true ]
    then
        var=$(i3-msg -t get_tree | jq  -r '.nodes[] | .. |select(.type?=="workspace") | {(.name): [.nodes[] | .. | select(.class?!=null) | .class] | unique | join(" ")} | keys_unsorted[0]+"|"+.[]' | awk '/^[a-zA-Z 0-9]/')
        foc=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused).name')
        current_wsp=" "
        while IFS= read -r line
        do 
            name=$(echo $line | awk -F"|" '/^[0-9]/ {gsub(/?[0-9]/, "", $0); print $1}');
            classes=$(echo $line | awk -F"|" '/^[0-9]/ {print $2}');
            if [[ $name == $foc ]]
            then
                current_wsp+="%{F"${foc_wsp_fore}"}"
                current_wsp+=$(GetNames $name $classes)
                current_wsp+="%{F"${foreground}"}"
            else
                current_wsp+=$(GetNames $name $classes)
            fi
            current_wsp+=" "${sep_l_right}" "
        done < <(printf '%s\n' "$var") 
    fi
    echo -e -n $current_wsp
}
        

Battery(){
  BATPER=$(acpi --battery | awk -v fore=${foreground} -v col_car=${color22} -v col_alt=${color1} -v ic_char=${icon_charging} -v ic_0=${icon_battery_1} -v ic_1=${icon_battery_2} -v ic_2=${icon_battery_3} -v ic_3=${icon_battery_4} -v ic_4=${icon_battery_5} 'BEGIN{FS="[,:]"}{retval=""; gsub(/[" "%]/, ""); 
                                  if($2 != "Discharging")
                                    retval="%{F"col_car"}"ic_char" "$3"%%""%{F"fore"}";
                                  else{
                                    if($3 < 10)
                                      retval="%{F"col_alt"}"ic_0" "$3"%%%{F"fore"}"
                                    else if($3 < 30)
                                      retval=ic_1" "$3"%"
                                    else if ($3 < 50)
                                      retval=ic_2" "$3"%"
                                    else if($3 < 80)
                                      retval=ic_3" "$3"%"
                                    else
                                      retval=ic_4" "$3"%"
                                  }
                                  print retval}')
  echo -n $BATPER                    
}

CPU (){
  cpu_per=$(top -bn 1 | egrep '^\s' | awk -v fore=${foreground} -v col_alt=${color1} -v ic=${icon_cpu} 'NR> 1 {perc+=$9} END {perc/=4;perc = int(perc); retval=perc>80?"%{F"col_alt"}"ic" "perc" %%%{F"fore"}":ic" "perc" %"; print retval}')
  cpu_fan_temp=$(sensors asus-isa-0000 | grep "temp\|fan" | tr -d ' ' | tr '\n' ':' | awk -v fore=${foreground} -v col_alt=${color1} -F":" '{gsub("+", ""); retval=int($4)>90?"%{F"col_alt"}"$4"%{F"fore"} | ":$4" | "; print retval$2}')
  echo -n $cpu_per" | "$cpu_fan_temp
}

Volume(){
  vol=$(amixer -c 1 get Master | grep Mono: | awk -v ic_on=${icon_vol} -v ic_off=${icon_vol_mute} '{gsub(/[\[\]]/, ""); if($6=="off") print ic_off; else print ic_on" "$4}')
  echo -n $vol
}

Ram() {
  ram=$(top -bn1 | grep "MiB Mem" | awk -v ic=${icon_mem} '{printf "%s %0.2f Gb\n",ic, $8/1000}')
  echo -n $ram
}

while true; do
  echo "%{F${foreground}}%{l}$(Workspaces)%{r}$(Nvidia) ${sep_l_left} $(CPU) ${sep_l_left} $(Ram) ${sep_l_left} $(Volume) ${sep_l_left} $(Battery) ${sep_l_left} $(Clock)%{F-}%{B-}"
        sleep 0.01
done
