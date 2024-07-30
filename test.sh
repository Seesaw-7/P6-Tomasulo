for i in $(find ./tests -name \*.s); do # Not recommended, will break on whitespace
    filename=$(basename -- "$i")
    extension="${filename##*.}"
    filename="${filename%.*}"
    make output/$filename
done

for i in $(find ./tests -name \*.c); do # Not recommended, will break on whitespace
    filename=$(basename -- "$i")
    extension="${filename##*.}"
    filename="${filename%.*}"
    make output/$filename
done
