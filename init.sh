mkdir -p days/day$1
cd $_
touch test.txt input.txt
tee part1.s part2.s < ../template.s > /dev/null
