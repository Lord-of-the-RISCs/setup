xmlFile="gecos-hls/gecos-software.p2f"
locs=""
ius=""
firstLoc=true
firstIu=true
if [ -f "$xmlFile" ]; then
    while IFS= read -r line; do
        if [[ $line == *"<iu "* ]]; then
            id=$(echo $line | grep -oP "id='\K[^']+")
            while IFS= read -r repoLine && [[ $repoLine != *"</iu>"* ]]; do
                if [[ $repoLine == *"<repository "* ]]; then
                    location=$(echo $repoLine | grep -oP "location='\K[^']+")
                    if [ "$firstLoc" = false ]; then
                        locs+=", "
                    fi
                    firstLoc=false
                    locs+=$location
                fi
            done < <(tail -n +$(grep -n -m 1 "$line" $xmlFile | cut -d: -f1) $xmlFile)
            if [ "$firstIu" = false ]; then
              ius+=", "
            fi
            firstIu=false
            ius+="$id"
        fi
    done < $xmlFile
else
    echo "$xmlFile not found!"
fi
eclipse -nosplash -application org.eclipse.equinox.p2.director -data "$1/workspace" -repository "$locs" -installIUs "$ius"
