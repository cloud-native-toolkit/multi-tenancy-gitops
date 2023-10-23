# Sterling File Gateway and FileZila Connection Configurations

This is a step by step guide on how to configure SFG to be able to connect from FieZila to it for demo purposes.


## Table of contents
- [Cloud Native Toolkit - GitOps Production Deployment Guide](#cloud-native-toolkit---gitops-production-deployment-guide)
  - [Table of contents](#table-of-contents)
  - [Pre-requisites](#pre-requisites)
    - [Red Hat OpenShift cluster](#red-hat-openshift-cluster)
    - [CLI tools](#cli-tools)
    - [IBM Entitlement Key](#ibm-entitlement-key)
  - [Setup git repositories](#setup-git-repositories)
    - [Tasks:](#tasks)
  - [Install and configure OpenShift GitOps](#install-and-configure-openshift-gitops)
    - [Tasks:](#tasks-1)
  - [Bootstrap the OpenShift cluster](#bootstrap-the-openshift-cluster)
    - [Tasks:](#tasks-2)
  - [Select resources to deploy](#select-resources-to-deploy)
    - [Tasks:](#tasks-3)


## Pre-requisites

1.	Modify Openshift helm chart values to change the ASI backendService node type from ClusterIP to NodePort

2.	Copy the port number under ASI backendService node because you will need it when creating the B2bi adapter

## SFG Configurations

### New SSH Key

1.	Navigate to the Sterling File Gateway server

2.	Follow the [documentation](https://www.ibm.com/docs/en/b2b-integrator/6.1.0?topic=adapter-generate-new-ssh-host-identity-key) to generate a New SSH Host Identity Key that will be used when creating a B2bi adapter


### Create B2bi Adapter

1. Create a SFTP server adapter by following the [documentation](https://www.ibm.com/docs/en/b2b-integrator/6.1.0?topic=z-sftp-server-adapter) and screenshot below

2. Use one of the ports you used for the ASI nodes in the helm charts values as shown below ( This port has to match the port used for the ASI node in your helm chart on Openshift)

![SFTP-Server-Adapter-Screenshot](/doc/images/sftp-server-adapter.png)

💡 **NOTE** You need to create a community and a partner and that should create all the required users, permissions, mailbox(s), virtual route(s), etc. that it needs needed for the adapter to work.

### Create Community

1. Login to your Sterling B2BI File Gateway and add /filegateway at the end of your B2bi Admin Console url to get to the communities UI

    ```bash
    https://asi-b2bi-prod.------------------------------------/filegateway/
    ```

2. Click Participants  Communities

3.	Enter community name

4.	Check “Partner Listens for Protocol Connections” and “SSH/SFTP”

5.	Choose to enable notifications for partners yes or no based on preference

6.	Click finish and community will be created

### Create Partner

1.	Click Participants  Partners

2.	Under partners, click create

3.	From the community dropdown, select the community you just created in the previous step, then click next

4.	In the partner information screen, enter the required partner information, then click next

5.	In the user account screen, check local authentication type
6.	Enter a username and password and save them ( you will need them to connect later)

7.	Leave the password policy dropdown blank, and leave the rest of the default timeout session as is

8.	Enter any given name and surname and then click next

9.	Check the “Partner is a consumer of data” and “Partner will initiate the connection to consume data”

10.	Also check “Partner is a producer of data”, then click next

11.	In the initiate connection setting section, answer YES to “will the partner user either SSH/SFTP or SSH/SCP protocol” question, and NO to “will the partner use an authorized user key to authenticate” question, and click next

12.	In the PGP settings section, answer NO to both questions, and click next

13.	Confirm your partner values and click finish to create the partner

### Create Channel Template

1.	Click Routes  Templates

2.	Under templates, click create

3.	Enter template name on the top of the page right under the navigation tabs

4.	Select Static template type and click next

5.	Select None for special characters and click next

6.	Under producer group, click add, then open the dropdown menu and select “All Partners”

7.	Under consumer group, click add, then open the dropdown menu and select “All Partners”, then click next

8.	Skip the provisioning Facts by clicking next

9.	Under Producer File Structure, click Add, select “Unknown” from the dropdown menu

10.	In the File name pattern, enter “.+”, and leave the File name pattern group face names field blank, then click save and click next

11.	Under delivery channel description, click Add

12.	Leave the pattern for consumer maibox path as is

13.	Check the 2 checkbox below it

14.	Under consumer file structure, click Add

15.	Select “Unknown” from the consumer file type dropdown menu

16.	Enter the following in the file name format field and click save, then click save

    ```bash
    ${ProducerFileName}_${tYmdHMSL:RoutingTimestamp}
    ```

17.	You should get a popup message that you routing channel template has been successfully created

### Create Channel

1.	Navigate to Routes

2.	Click on create on the bottom right-hand side of the screen

3.	Select the channel template you just created from the routing channel template dropdown menu

4.	Select the partner you created earlier as well in the next 2 dropdown menus for the producer and consumer

5.	Click Save and you should get a success popup message

## Validation section

1. 	Open FileZilla

2.	Use your B2bi server URL or server public IP

3.	User the same port you used to configure the B2bi adapter 

4.	The partner username and password created while configuring communities

5.	Select SFTP-SSH File Transfer Protocol

6. You should get connection successful message


                 Happy Connecting!!!
