COLUMNS=$(tput cols)
title="Hello world!"
printf "%*s\n" $(((${#title}+$COLUMNS)/2)) "$title"
