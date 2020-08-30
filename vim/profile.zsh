
# useful command to test vim startup:
timevim() {
    for i in {1..20}; do 
        vim --startuptime start$i.log; 
    done

    find start* -exec grep STARTED {} \; | cut -d' ' -f1
}
