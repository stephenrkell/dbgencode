#!/bin/bash

dir1="$1"
dir2="$2"
regexp="$3"

shift; shift; shift; diffargs="$@"
if [[ -z "$diffargs" ]]; then diffargs="-u5" ; fi

# Diff the asm of common .s files, after filtering out lines matching regexp

{ { cd "$dir1" && find -name '*.s' | sort; }; 
  { cd "$dir2" && find -name '*.s' | sort; } | uniq -c | grep '^[[:blank:]]*2'; } | \
while read f; do
    diff $diffargs <( sed "/$regexp/ d" "$dir1"/"$f" ) \
                   <( sed "/$regexp/ d" "$dir2"/"$f" )
done
