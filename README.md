Source code which runs the site: [osr4rightstools.org](https://osr4rightstools.org)

## Introduction

OSR4Rights Tools is a website providing open source tools for human rights investigators. The website provides the secure user experience and servers needed to run the tools.

There are 2 tools currently in production

- Face Search which looks for a target face in an image, in many other images. eg give the tool a .jpg with a single face in it, and many other .jpgs, and it will find that person in the other .jpgs

- Hate Speech which given a csv of text will classify how much hate speech the text contains

Both of these tools, and the website are Open Source.  There are no paid for libraries used in any of this code.

![Face Search](https://github.com/djhmateer/osr4rights-tools/blob/main/src/OSR4Rights.Web/wwwroot/screenshots/overall.jpg?raw=true)

Screenshot of the Face Search page showing upload, samples and sample output.

## Context

The team is:

- [Prof Yvonne McDermott Rees](https://osr4rights.org/team/), Swansea University. Team lead.
- [Dr Phil Bartie](https://osr4rights.org/team/), Heriot-Watt University. Developed the FaceSearch tool 
- [Dr Riza Batista-Navarro](https://osr4rights.org/team/), University of Manchester. Developed the HateSpeech tool
- [Dave Mateer](https://davemateer.com), [hmsoftware.co.uk](https://hmsoftware.co.uk) - Develop the website (this repository)

The initial budget of the website was approx £12k.

The budget to keep the website going for 3 years is approx £5k, which is not enough to rent a GPU powered machine for all that time, so we use the cloud to spin up resources when needed


## Constraints

Evergreen browsers are supported only. Javascript is required for file uploading.


## Principles

The [ASP.NET Core](https://dotnet.microsoft.com/learn/aspnet/what-is-aspnet-core) website is deployed onto an Ubuntu 20.04 LTS VM on Microsoft Azure Europe West (Holland)

The [Kestrel ASP.NET Core webserver](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-5.0) has a reverse proxy in front of it [Nginx](https://www.nginx.com/). This is to serve the SSL Certificate, and to allow the [Tus.io](https://tus.io/) file uploader to work properly. 

DNS is handled by [DNSimple](https://dnsimple.com) and the deployment script uses their API to automatically change DNS records when a new server comes online.

Data Persistence is [SQL Azure](https://azure.microsoft.com/en-gb/products/azure-sql/database/#overview) (Authentication Authorisation and workflow) and [Azure File Share](https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-create-file-share?tabs=azure-portal) (results files and cookies)

The website runs [Background Services](https://www.pluralsight.com/courses/building-aspnet-core-hosted-services-net-core-worker-services) which monitor internal queues (Channels) which in turn spin up other VM's in Azure when needed.

The queues allow the website to remain responsive all the time, as work is 'queued'. The queues are not resilient to a server and process restart. They are in memory only.


### Data Security and Flow

User uploads a file using the tus.io protocol (see below). The webserver listens on the route `/files`

![Upload](https://github.com/djhmateer/osr4rights-tools/blob/main/src/OSR4Rights.Web/wwwroot/screenshots/upload.jpg?raw=true)

Can pause the upload and it will resume. If you connection is interrupted (eg machine reboot), it will resume.

Tus files are stored in

`/tusFileStore` (or `c:\tusFileStore` on dev) - set in AppConfiguration.cs

```bash
-rw-r--r--  1 www-data www-data         1 Sep 20 09:48 1a89dc2e28ac46d7bcc9b0906405d269.chunkcomplete
-rw-r--r--  1 www-data www-data 216553987 Sep 20 09:48 1a89dc2e28ac46d7bcc9b0906405d269
-rw-r--r--  1 www-data www-data         1 Sep 20 09:46 1a89dc2e28ac46d7bcc9b0906405d269.chunkstart
-rw-r--r--  1 www-data www-data        33 Sep 20 09:46 1a89dc2e28ac46d7bcc9b0906405d269.expiration
-rw-r--r--  1 www-data www-data        75 Sep 20 09:46 1a89dc2e28ac46d7bcc9b0906405d269.metadata
-rw-r--r--  1 www-data www-data         9 Sep 20 09:46 1a89dc2e28ac46d7bcc9b0906405d269.uploadlength
```

Once the file has been successfully uploaded via `face-serach.cshtml`, control flow passes to `face-search-go.cshtml`

Validation happens now by unzipping the file to `/osrFileStore/123456789`

`123456789` - a temp unixtime directory that the tusFile would be unzipped into by face-search-go which will guard against bad files. It checks zip is okay, and directories are okay.

Only after validation of the file is complete is it copied to `/osrFileStore` as `job123.tmp`

All tus files for this upload are then deleted. So no complete file is every saved in /tusFileStore (and partial is only saved for 1 day)


/osrFileStore (or c:\osrFileStore)

job123.tmp - this would be the renamed 216MB file from /tusFileStore above

This full path and filename is then passed to the queue (Channel) which is picked up by `FaceSearchFileProcessingService`

This service deletes the /osrFileStore file when it is finished

Results are saved into an Azure File Share which is mounted on `/mnt/osrshare`

```bash
# facesearch output
/mnt/osrshare/downloads/214
  results.html
  results214.zip
  match_face2.jpg etc..
  target_target.jpg

# hatespeech output
/mnt/osrshare/downloads/210
  results.html
  results210.csv
```

All references to these files are handled through the `/downloads.cshtml` page which ensures authentication and authorisation.

Username and password for this file share are handled like all secrets in this solution - in the build scripts. See `/secretsRedacted` folder for the template.
  
### Cookie Keys

Stored in Azure File Share under /mnt/osrshare/osr-cookie-keys

This is so that user doesn't have to login when a new version of the code is deployed and a new VM is created.


### Worker VM's 

Each tool has its queue which feeds jobs onto a worker VM.

The worker VM spins up when needed, then spins down according to rules (each tool has its own rules)

Using raw VM's it is much easier to debug. Initially when getting the GPU code working on nVidia based machines, this was very complex, so having a raw VM was invaluable. In essence negating a layer of complexity (if we used Docker). As the client was not concerned on the startup times on the VM, we chose to run raw VM's.


## Software Architecture

Razor pages website using .NET5
Integration testing using xunit
DB Project to hold the db schema

Database orm is [https://github.com/DapperLib/Dapper](https://github.com/DapperLib/Dapper)
SQL Retry's are handled by [](Polly)

Async all the way up, is used throughout the app to alleviate resource consumption

Configuration is in App.Configuration

Outbound emails are handled by [Postmark](https://postmarkapp.com/)

### Authentication and Authorisation

Slimmer version of MS Identity.

3 wrong passwords allowed before lockout

### Tus Resumable File Uploader

[https://tus.io](tus.io) is a resumable file uploader to help large files be uploaded successfully. We are using [https://github.com/tusdotnet/tusdotnet](https://github.com/tusdotnet/tusdotnet) for the server implementation.


## Deployment

Deployment is using The Azure CLI via a BASH script. I use WSL2 on Windows with the relevant environment variables set:

The entire website can be deployment with 1 command

```bash
/infra/infra.azcli
```


### Secrets

Copy the /secretsRedacted directory to /secrets. This is ignored in source control (.gitignore)

### SSL Certs

We are using Let's Encrypt, and manually requesting it through [https://dnsimple.com/a/63829/domains/osr4rightstools.org/ssl_certificates](DNSimple).

Then putting the .pem (which contains the primary certificate and the intermediate certificates) and .key (private key) files in /secrets folder (which is not checked into source control)

The [/infra/infra.azcli](/infra/infra.azcli) file scp's these files onto the newly created VM. The [infra/nginx.conf](infra/nginx.conf) then picks up these files.


### Cloud

The Azure login that controls this is dave@hmsoftware.co.uk

To manually see all VM's use [https://portal.azure.con](portal.azure.com)

### Creating or Updating Working VM Images

Conceptually we create a build script for a VM to do the processing, take a snapshot of it, then spin up that snapshot whenever we need it.

[Infra.azcli](https://github.com/djhmateer/osr4rights-tools/blob/main/1faceSearchInfraGPU/infra.azcli) for facesearch shows the build script for the VM.

[create_facesearch_gpu.sh](https://github.com/djhmateer/osr4rights-tools/blob/main/1faceSearchInfraGPU/create_facesearch_gpu.sh) is where the main work is - bash script detailing the dependencies of the VM.

You can see in this file that FaceSearch needed some specific versions of libraries to get the Python/C GPU running as expected.  


### DB Updates

Use the Database project inside /src to get the correct schema

[insertData.sql](https://github.com/djhmateer/osr4rights-tools/blob/main/src/Database/insertData.sqlX) inserts the needed data for the workflows.


## Operation and Support

New users need to be manually approved to go from Tier1 (only allowed to run the samples) to Tier2 (allowed to upload their own files)


Admins (which is another Role) have an /admin page to change the users Roles.

Admins can also change the User to Disabled for users who are not real, or we don't want on the system

Admins can unlock a Users account (if LoginStateId = 4 LockedOutDueTO3WrongPasswords)


If the VM is rebooted or the process unexpectely restarts (it is using systemctl). See [/infra/create_webserver.sh](/infra/create_webserver.sh). Then the internal queue will disappear. It is not resilient of a process restart

## Backups

DB has a diff backup of every 12 hours and a 7 day.

Azure File Share is on the LRS (Locally Redundant) system.


## Debugging and Log Files

In order of priority:

Users can see more information from the 'Show Logs' button on a result page eg [https://osr4rightstools.org/result/146](https://osr4rightstools.org/result/146)

Logon to the webserver using sshkeys (from the machine where site was deployed from). I've got SSHKeys enabled - desktop machine and laptop machine.

```bash
# application logs
/var/www/logs/info01012021.txt
/var/www/logs/warning01012021.txt

# os logs
/var/log/syslog

# nginx logs
/var/log/nginx
```

## Development Environment

To get this code working locally on your dev machine, clone this repo. I use [VS2019 Community]() and make sure it is fully up to date.

You'll need to create a local version of the db, so install MSSQL.

You'll need an Azure account with access to the appropriate VM's - specifically my Azure Developer Account wouldn't give me any quota on the NC4as_T4_v3 GPU machine which we use for FaceSearch. So you'll need a paid account.

### MFA

Email MFA is ready to go - there are columns in Login for this: MfaFailedAttempts, MfaCode, MfaSendDateTimeUtc

Email2FAWhiteList table could be implemented: Email2FAWhiteListId, LoginId, IPAddress, LastAccessedDateTimeUtc.

Then code would have to be written that said.. perhaps.. if the user starts coming from a different country then do an Mfa check.

MFA is hard to get right, and not get in the way of users.

## Conclusion

As the budget was limited, I focussed efforts on the implementation of the tools. Design decisions reflect the desire to get it working quickly, and in the simplest manner. A good example of this is why we chose not to use Docker, resilient queues, an API layer, and a pleathora of other nice to haves. It also reflects what I knew well and could get working quickly.

Phase 1 of the project was a success with it being delivered on budget, and phase 2 (July 2021 - July 2022) is now happening.
