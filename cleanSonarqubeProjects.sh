#!/bin/bash

if [ -z "$SONAR_AUTH_TOKEN" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Not found SONAR_AUTH_TOKEN, GITHUB_TOKEN"
  exit 1
fi

page=1
result=$(curl -s -X GET -L -H "Authorization: bearer $GITHUB_TOKEN"  "https://api.github.com/orgs/eea/repos?type=all&per_page=100&page=$page")

echo "" >list_archived

while [ $(echo -e "$result" | grep name | wc -l) -ne 0 ]; do
  echo -e "$result" | jq -r ".[] | select(.archived) | .name" >>list_archived
  page=$(($page + 1))
  result=$(curl -s -X GET -L -H "Authorization: bearer $GITHUB_TOKEN"  "https://api.github.com/orgs/eea/repos?type=all&per_page=100&page=$page")
done

page=1
result=$(curl -s -u "${SONAR_AUTH_TOKEN}:" "${SONAR_HOST_URL}api/projects/search?ps=500&p=$page")

echo "" >list_sonarqube

while [ $(echo -e "$result" | grep name | wc -l) -ne 0 ]; do
  echo -e "$result" | jq -r '.components[].key ' >>list_sonarqube
  page=$(($page + 1))
  result=$(curl -s -u "${SONAR_AUTH_TOKEN}:" "${SONAR_HOST_URL}api/projects/search?ps=500&p=$page")
done

cat list_sonarqube >list_projects_master

rm -rf list_to_delete
touch list_to_delete
  
for i in $(cat list_projects_master); do
  echo "------------------------------------"
  echo "$i"
  if [ $(grep "^$i$" list_archived | wc -l) -eq 1 ]; then
    echo "It is archived"
     echo "$i"  >> list_to_delete
 fi
done
  
  if [ $(cat list_to_delete | wc -l) -gt 0 ]; then
    echo "Will delete:"
    projects=""
    for i in $(cat list_to_delete); do projects="${projects}${i},"; done
    echo "$projects"
    curl -s -XPOST -u "${SONAR_AUTH_TOKEN}:" "${SONAR_HOST_URL}api/projects/bulk_delete?projects=$projects"
  fi


check_lines=$(curl -s -XPOST -u "${SONAR_AUTH_TOKEN}:" https://sonarqube.eea.europa.eu/api/v2/entitlements/license)

number=$(echo -e $check_lines | jq -r '.loc')
max_number=$(echo -e $check_lines | jq -r '.maxLoc')

echo "Number of lines is $number out of $max_number"

