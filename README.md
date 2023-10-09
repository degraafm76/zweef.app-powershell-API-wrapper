# zweef.app-powershell-API-wrapper
Powershell API wrapper for zweef.app an administration system for gliding clubs.

Attention: This wrapper doesn't use the very limited official API (https://documenter.getpostman.com/view/25434528/2s8ZDX5PRi) so any changes in the API will break this wrapper.

# Installation
1: Download zweefapp.psm1 in a folder of your choice and change the club parameter in the module if needed (default is the club i'm flying > zvc)

2: Run powershell command import-module zweefapp.psm1

3: Connect to zweef.app with the command connect-zweefapp

4: You can list the available commands with get-command -Module zweefapp

