#!/bin/sh 

 if [ -z "$SONARQUBE_TAG" ] || [ -z "$SONAR_HOST_URL" ] || [ -z "$SONARQUBE_TOKEN" ];
	 echo "NEED VARIABLES"
	 exit 1
 fi

 #SONARQUBE_TAG=demo-kitkat.dev2aws.eea.europa.eu

 project_result=$(curl -s "${SONAR_HOST_URL}api/components/search_projects?filter=tags%20%3D%20$SONARQUBE_TAG" )
 for i in $(echo -e "$project_result" | jq -r '.components[].name'); do tags=$(echo -e "$project_result" | jq -r ".components[] | select (.name == \"$i\") | .tags[]" | tr '\n' ',' | sed "s/$SONARQUBE_TAG,//"); curl -XPOST  -u "${SONARQUBE_TOKEN}:" "${SONAR_HOST_URL}api/project_tags/set?project=$i&tags=$tags"; echo $i; echo $tags; echo "--------------------"; done
 



