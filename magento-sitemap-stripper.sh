#!/bin/bash

if [[ -z ${2} ]]
then
  echo "Usage: $0 <category|subcategory|product> <http://www.example.com/sitemap.xml>"
  exit 1
fi

case "${1}" in
  category)
    curl -sL ${2} | xmllint --format - | grep -B3 "<priority>0.5</priority>" | grep "\<loc\>" | sed 's/<[/]loc>//' | cut -d "/" -f 4,5 | grep -v "/"
    ;;

  subcategory)
    curl -sL ${2} | xmllint --format - | grep -B3 "<priority>0.5</priority>" | grep "\<loc\>" | sed 's/<[/]loc>//' | cut -d "/" -f 4,5 | grep "/"
    ;;

  product)
    curl -sL ${2} | xmllint --format - | grep -B3 "<priority>1.0</priority>" | grep "\<loc\>" | sed 's/<[/]loc>//' | cut -d "/" -f 4
    ;;

  *)
    echo "Usage: $0 <category|subcategory|product> <http://www.example.com/sitemap.xml>"
    exit 1
    ;;
esac
