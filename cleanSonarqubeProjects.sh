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

cat list_sonarqube | grep -E "\-master$" | sed 's/-master$//' >list_projects_master

for i in $(cat list_projects_master); do
  rm -rf list_to_delete
  touch list_to_delete

  echo "------------------------------------"
  echo "$i"
  if [ $(grep "^$i$" list_archived | wc -l) -eq 1 ]; then
    echo "It is archived"
    if [ $(grep -E "^$i-.*-master$" list_sonarqube | wc -l) -ne 0 ]; then
      grep "^$i\-master$" list_sonarqube >> list_to_delete
      grep "^$i\-develop$" list_sonarqube >> list_to_delete
      grep -E "^$i\-PR\-[0-9]*$" list_sonarqube >> list_to_delete
    else
      grep "^$i\-" list_sonarqube >> list_to_delete
    fi
  else

    if [ $(grep "^$i\-PR\-[0-9]*" list_sonarqube | wc -l) -eq 0 ]; then
      echo "There are no PR projects"
    else
      echo "Check closed PRs"
      curl -s -X GET -L -H "Authorization: bearer $GITHUB_TOKEN"  "https://api.github.com/repos/eea/$i/pulls" | jq -r '.[].number' >list_prs
      if [ $? -eq 0 ]; then
        echo "------------"
	echo "$i has this opened PRs:"
        cat list_prs
        echo "------------"
        for j in $(grep "^$i\-PR\-[0-9]*" list_sonarqube); do
          pr=$(echo $j | sed "s/^$i\-PR\-//")
          if [ $(grep "^$pr$" list_prs | wc -l) -eq 0 ]; then
            echo "$j" >> list_to_delete
          fi
        done
      else
        echo "Received error getting PRs of $i, skipping check"
      fi

    fi

    if [ $(grep -E "^$i-.*-master$" list_sonarqube | wc -l) -eq 0 ]; then
      grep "^$i\-.*$" list_sonarqube | grep -v "\-master$" | grep -v "\-develop$" | grep -v "\-PR\-.*$" >list_branches
      if [ $(cat list_branches | wc -l) -eq 0 ]; then
        echo "There are no branch projects"
      else
        echo "Will check :"
        cat list_branches
        curl -s -X GET -L -H "Authorization: bearer $GITHUB_TOKEN"  "https://api.github.com/repos/eea/$i/branches" | jq -r '.[].name' >list_branch
        if [ $? -eq 0 ]; then
          echo "------------"
	  echo "$i has this opened branches:"
          cat list_branch
          echo "------------"
          for j in $(cat list_branches); do
            br=$(echo $j | sed "s/^$i\-//")
            if [ $(grep "^$br$" list_branch | wc -l) -eq 0 ]; then
              echo "$j" >> list_to_delete
            fi
          done
        else
          echo "Received error getting branches of $i, skipping check"
        fi
      fi

    fi
  fi
  
  if [ $(cat list_to_delete | wc -l) -gt 0 ]; then
    echo "Will delete:"
    projects=""
    for i in $(cat list_to_delete); do projects="${projects}${i},"; done
    echo "$projects"
    curl -s -XPOST -u "${SONAR_AUTH_TOKEN}:" "${SONAR_HOST_URL}api/projects/bulk_delete?projects=$projects"
  fi


done
