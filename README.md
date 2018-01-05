# InsomniaX
InsomniaX - Keep your Mac awake the easy way

## Description
It always has been a missing feature: disabling the sleep mode on a Apple Laptop. Who does not want to use it as a big juke-box or go warwalking? The best looking server ever, especially at about one-inch height. This small utility is what you will want. This small utility acts as a wrapper to the Insomnia kernel extension.

## Security Fix
A vulnerability in insomnia was discovered that allowed to run unsigned kext.
A fix proposed by Mark Wadham is available here: https://m4.rkw.io/blog/security-fix-for-insomniax-218.html

1. Install Insomnia X to /Applications
2. Download the patch from: https://m4.rkw.io/insomnia_218_patch.sh.txt
3. (Optional) Delete the .txt extension
4. Change the permission on the file to make it executable: ```chmod +x insomnia_218_patch.sh```
5. Run the patch script: ```./insomnia_218_patch.sh```

## Installing On OSX 10.12 and afterward
It seems that on systems with gatekeeper active, the kext module is not correctly loaded, if when the option *Disable Lid Sleep* is pressed the icon doesn't change you are most likely affected. In that case use the following workaround:

1. Disable Gatekeeper: ```sudo spctl --master-disable ```
2. Launch InsomniaX and enable the option ```disable lid sleep```, fill out the administration password prompt if needed
3. Rejoice, InsomniaX should be working and the kext should now be trusted by the system
4. Re-Enable Gatekeeper:
  - Either use: ```sudo spctl --master-enable```
  - Or change the selector in Preferences->Security & Privacy->Generic back to AppStore & Signed Apps (Or even the more strict AppStore Only)

## Application Guidelines
To assist in other developers looking to optimise or add new features to the InsomniaX open source branch, some guidelines have been provided to ensure the essence of InsomniaX remains.
- Insomnia KEXT should be as light weight as possible (KISS).
- Insomnia KEXT should only be loaded when required by InsomniaX (This ensures InsomniaX remains passive and does not affect the system when rebooted or when InsomniaX is terminated).
- InsomniaX should have a clean and simple interface. If an option is not part of the core functionality, then it should be made available via either an preference item accessible by command line or an "advanced/hidden" preference panel.

## Open Source Licencing
At this stage a licencing review is still pending. We are aiming for a GPLv3 at this stage; however, we will need to determine if any of the code included is able to be licenced as such.

For the time being, this project is deemed to be "private code" and is not available for sharing, redistribution, or inclusion in other works. Also, all liabilities are waived.

With that being said, I am happy for people to contribute code changes, if anyone wants to fork the code they must include links to both this repo and the semaja2.net website as the original source.

## Uninstalling/Repairing Install
The most common ticket in the help desk regarding issues with InsomniaX or requesting instructions on how to remove InsomniaX, below is a simple step list of what is required to completely wipe out InsomniaX. If any problems exist after removing InsomniaX it should not be related to Insomnia as it works as a passive changing, in other words once its unloaded all changes are moved (Especially after a reboot, any trace should be gone).

1. Reboot the machine
2. Ensure InsomniaX is not running
3. Enter in terminal : defaults delete com.semaja2.InsomniaX (use net.semaja2.insomniax for InsomniaX 2.1 +)
4. Delete ~/Library/Application Support/InsomniaX (Use the terminal command “sudo rm -rf ~/Library/Application\ Support/InsomniaX”)
5. Delete /Applications/InsomniaX.app
6. If reinstalling download latest version from semaja2.net
