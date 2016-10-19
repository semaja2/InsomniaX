# InsomniaX
InsomniaX - Keep your Mac awake the easy way

## Description
It always has been a missing feature: disabling the sleep mode on a Apple Laptop. Who does not want to use it as a big juke-box or go warwalking? The best looking server ever, especially at about one-inch height. This small utility is what you will want. This small utility acts as a wrapper to the Insomnia kernel extension.

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
