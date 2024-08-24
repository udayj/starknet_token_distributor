**Brief Project Summary**

This project has a rudimentary implementation of a locked token and token distribution mechanism. 
Lets say, Project A wants to distribute its token TKT to its users but does not want them to immediately create sell pressure but rather unlock it after sometime.
They can issue a locked Token wTKT which is essentially an ERC20 without ability to approve / transfer / transfer_from. Users submit claim with signature which has been signed by a project approved oracle off-chain. The signature is verified and claimable amount of locked tokens are issued to the user. When swap period starts, users can transfer their locked tokens to the distributor contract and get back actual project tokens TKT.