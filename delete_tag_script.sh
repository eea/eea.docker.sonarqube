#!/bin/sh 

 if [ -z "$SONARQUBE_TAG" ] || [ -z "$SONAR_HOST_URL" ] || [ -z "$SONARQUBE_TOKEN" ]; then
	 echo "NEED VARIABLES"
	 exit 1
 fi

 #SONARQUBE_TAG=demo-kitkat.dev2aws.eea.europa.eu

 project_result=$(curl -s "${SONAR_HOST_URL}api/components/search_projects?filter=tags%20%3D%20$SONARQUBE_TAG" )

 echo "$project_result" 

 echo "------"
 for i in $(echo  "$project_result" | jq -r '.components[].name'); do 
	 echo $i
	 tags=$(echo "$project_result" | jq -r ".components[] | select (.name == \"$i\") | .tags[]" | tr '\n' ',' | sed "s/$SONARQUBE_TAG,//")
	 curl -XPOST  -u "${SONARQUBE_TOKEN}:" "${SONAR_HOST_URL}api/project_tags/set?project=$i&tags=$tags"
	 echo $tags
	 echo "--------------------"
 done
 



