#  [Lighwell] Framework Deploymet Guide

## B2bi deployment 

1. Follow the SFG-Recipe for your version fo B2bi integrator in a single namespce ( i.e `b2bi-prod`)

https://github.com/cloud-native-toolkit/multi-tenancy-gitops/blob/master/doc/sfg-recipe.md

>  💡 **NOTE IMPORTANT**  
    > Modify the B2bi datbase repo [step 2] before you deploy the B2bi DB

2. Modify the b2bi database reporisorty under muti-tenecy-gitops repo  bootstrap/single-cluster/2-services/argocd/instances/ ibm-sfg-db2-prod.yaml to,
```
quay.io/shadyattia/b2bi-db:v1.2
```

>  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` & sync ArgoCD. 

## Lightwell Deployment

### Deploy LW-DB

1.  Edit the Services layer `${GITOPS_PROFILE}/2-services/kustomization.yaml` by uncommenting the following lines to install the lightwell framework db2 database
```
yaml
- argocd/instances/ibm-lw-db2.yaml
```

>  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` & sync ArgoCD and wait for about 5 min untill the database is initiated

### Deploy Lightwell Framework

1. Under the services repo, open the lightwell-framework-instance
2. Under configmap, open the customer_LW_license_properties and modify the customer name and license
3. Open the application.properties and modify/update,
```
- All URLs to match your cluster
- All usernames and password if not using the defaults listed
- B2bi and LW databases IP addresses and port number
```
>  💡 **NOTE**  
    > Use the existing LW properties files as a guide when making these changes 
### Generate required k8s Secret

1. login to the cluster before you run the java commands 
2. Generate "encryption.key" and "portal.key" using the LwEncryption.jar
```
java -jar LwEncryption.jar -k portal.key
java -jar LwEncryption.jar -k encryption.key
```
### Update YAMLs

1. Update ${STORAGECLASS} in 3-Installation/lightwell-framework-instance/pvcs/lwfw-files-pvc.yaml
2. Update "image" as required in 3-Installation/lightwell-framework-instance/statefulsets/lwfw-statefulset.yaml

### Generate a SealedSecret (requires kubeseal cli)

1. ./3-Installation/Lightwell-Framework-Secrets/lwfw-secret.sh (./lwfw-secret.sh)
2.  Copy the generated SealedSecret into the Kustomize structure

cp 3-Installation/Lightwell-Framework-Secrets/lw-app-prop.yaml 3-Installation/lightwell-framework-instance/secrets/lw-app-prop.yaml

>  💡 **NOTE**  
    > Commit and Push the changes for `multi-tenancy-gitops` & sync ArgoCD. 

### Post installation Config 

> Post installation configuration once Lightwell Framework is deployed
    
1. Edit the `admin` account and grant it with the "APIUser" permission to be able to log in to B2Bi Customization > Customization view.
```
Accounts > User Accounts and search for "admin".
Grant it the "APIUser" permission in the "Permission" section, click save and Finish
```
2. Log in to Customization > Customization view
3. Click on CustomJar tab and click "Create CustomJar" button
```
- Vendor Name: LW
- Vendor Version: 1.0
- Jar Type: Library
- File: LWUtility.jar
- Target Path: DCL
- Click on "Save CustomJar" button
```
4. Click on CustomService tab and click "Create CustomService" button
```
- Service Name: LW-RuleService
- File: LwRuleService.jar
- Click on "Save CustomService" button

```
5. Click on CustomService tab and click "Create CustomService" button
```
- Service Name: LW-UtilityService
- File: LwUtilityService.jar
- Click on "Save CustomService" button
```

6. Click on CustomService tab and click "Create CustomService" button
```
- Service Name: LW-UtilsExternal
- File: LwUtilsExternal.jar
- Click on "Save CustomService" button
```
7. Click on PropertyFile tab and click "Create PropertyFile" button
```
- PropertyFile Prefix: customer_LW
- Property File: customer_LW.properties
- Click on "Save PropertyFile" button
```
> Update customer_overrides.properties for LW deployment (ie. set DB configurations)
9. Click on PropertyFile tab and edit "customer_overrides" PropertyFile
```
- Click on "customer_overrides" and select "General" tab
- Click on "Edit" button
- Property File: customer_overrides.properties
- Click on "Replace Existing Property File" checkbox
- Click on "Save PropertyFile" button
```
10. Edit "customer_LW" Property File
```
- Click on "customer_LW" Property File and select "Property" tab
- Modify the following properties:
    Property: DefaultEmail
    Property Value: <Email>
    Property: DefaultEmailSender
    Property Value: <Email>
    Property: ErrorAckEmail
    Property Value: <Email>
    Property: OverdueAckEmail
    Property Value: <Email>
    Property: PortalAuditEmail
    Property Value:: <Email>
    Property: DatabaseStorage
    Property Value: true
    Property: TempDirectory
    Property Value: /files
    Property: ArchiveOlderThanDays
    Property Value: <Days before archive>
    Property: ArchiveRootDirectory
    Property Value: /files/archive
```
> Log in to B2Bi Console
11. Deployment > Resource Manager > Import/Export
```
- Select "Import"
    File Name: EnvelopeExport.xml
    Passphrase: password
    Import All Resources: Select checkbox
    Click Next x3, Finish
- Select "Import"
    File Name: FrameworkExport.xml
    Passphrase: password
    Import All Resources: Select checkbox
    Click Next x3, Finish
```

> Issue: File too big so had to restart the application for customer_overrides to take effect
```
- From B2Bi console, Operations > System > Troubleshooter > Stop the System
- From the `asi` pod, go to the terminal window
    cd ibm/b2bi/install/bin
    ./hardstop.sh
    ./run.sh

Note: This will install the CustomJar and CustomServices along with the customer_overrides

Issue: Stopping the B2Bi service will cause the STS probes to restart the pod as its failing the check

Increase the configuration of the probes or remove as a workaround

NOTE: FrameworkExportSPE.xml is only used if ITXA is installed

```
12. Log in to B2Bi Console
```
- Deployment > Services > Configuration
- Search SMTP
    - Edit LW_SA_SMTP as needed
    - Click Save
- Search Portal
    - Edit LW_SA_HTTP_S1N1LOCAL_PORTAL
        HTTP Listen Port: 5580
    - Click Save
- Search b2bi
    - Edit LW_SA_LWJDBC_B2BI
        Pool Name: db2Pool
    - Click Save
```

### Validation

1. Log in to Lightwell Portal and check Framework Version
```
- Framework Management > Rules > Route Rules
    Click New and set the following:
        Document Type: 850
        Click Save
- Framework Management > Rules > Send Rules
    Click New and set the following:
        Document Type: 850
        Send BP: LW_BP_SEND_EMAIL
        Subject Mask: 850
        Email Recipient: <Email>
        Click Save
- Framework Management > Test Flow
    Protocol: PROXY
    User ID: admin
    File: Partner1_8850.edi
    Click Submit
- Document Visibility > Submit File to B2Bi
    Protocol: PROXY
    User ID: admin
    File: Partner1_850.edi
    Click Submit
    Click "Show Documents"
```