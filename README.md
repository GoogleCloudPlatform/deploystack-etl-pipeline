# DeployStack - ETL Pipeline 

This architecture is for one data pipeline approach called 
ETL— or extract, transform, load — which allows you to maximize flexibility 
in how you transform your data while also providing dynamic scaling to 
handle large amounts of incoming data and processing demands. 
 
It uses Cloud Storage for landing data, Dataflow as a managed service 
for processing data, BigQuery as a destination data warehouse, and 
Cloud Composer, as an orchestration tool that helps you 
author, schedule, and monitor data pipelines.

![ETL Pipeline architecture](/architecture.png)

## Install
You can install this application using the `Open in Google Cloud Shell` button 
below. 

<a href="https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2FGoogleCloudPlatform%2Fdeploystack-etl-pipeline&shellonly=true&cloudshell_image=gcr.io/ds-artifacts-cloudshell/deploystack_custom_image" target="_new">
        <img alt="Open in Cloud Shell" src="https://gstatic.com/cloudssh/images/open-btn.svg">
</a>

Clicking this link will take you right to the DeployStack app, running in your 
Cloud Shell environment. It will walk you through setting up your architecture.  

## Cleanup 
To remove all billing components from the project
1. Typing `deploystack uninstall`

This is not an official Google product.
