contract DougEnabled {
    address DOUG;
    
    function setDougAddress(address dougAddr) returns (bool results){
        
        if(DOUG != 0x0 && dougAddr != DOUG){
            return false;
        }
        DOUG = dougAddr;
        return true;
        
    }
    
    function remove(){
        if(msg.sender == DOUG){
            suicide(DOUG);
        }
    }
}

contract Doug {
    address owner;
    
    mapping (bytes32 => address) public contracts;
    
    function Doug(){
        owner = msg.sender;
    }
    
    function addContract(bytes32 name, address addr) returns (bool result)
    {
        if(msg.sender != owner){
            return;
        }
        
        DougEnabled de = DougEnabled(addr);
        
        if(!de.setDougAddress(address(this))){
            return false;
        }
        contracts[name] = addr;
        return true;
    }
    
    function removeContract(bytes32 name) returns (bool result){
        if(contracts[name] ==0x0){
            return false;
        }
        if(msg.sender != owner){
            return;
        }
        contracts[name] = 0x0;
        return true;
    }
    
    function remove(){
        
        if(msg.sender == owner){
            address fm = contracts["fundmanager"];
            address perms = contracts["perms"];
            address permsdb = contracts["permsdb"];
            address bank = contracts["bank"];
            address bankdb = contracts["bankdb"];
            
            //Remover Everything
            if(fm != 0x0){ DougEnabled(fm).remove();}
            if(perms != 0x0){DougEnabled(perms).remove();}
            if(permsdb != 0x0){DougEnabled(permsdb).remove();}
            if(bank != 0x0){ DougEnabled(bank).remove(); }
            if(bankdb != 0x0){DougEnabled(bankdb).remove(); }
            
            selfdestruct(owner);
        }
    }
}

contract ContractProvider {
    function contracts(bytes32 name) returns (address addr){}
}

contract FundManagerEnabled is DougEnabled {
    function isFundManager() constant returns (bool) {
        if(DOUG != 0x0){
            address fm = ContractProvider(DOUG).contracts("fundmanager");
            return msg.sender == fm;
        }
        return false;
    }
}

contract PermissionsDb is DougEnabled {
    
    mapping (address => uint8) public perms;
    
    function setPermission(address addr, uint8 perm) returns (bool res){
        if(DOUG != 0x0){
            address permC = ContractProvider(DOUG).contracts("perms");
            if(msg.sender == permC){
                perms[addr] = perm;
                return true;
            }
            return false;
        }else{
            return false;
        }
    }
}
 contract Permissions is FundManagerEnabled {
     
     function setPermission(address addr, uint8 perm) returns (bool res){
         if(!isFundManager()){
             return false;
         }
         address permdb = ContractProvider(DOUG).contracts("permsdb");
         if(permdb == 0x0 ){
             return false;
         }
         return PermissionsDb(permdb).setPermission(addr, perm);
     }
 }

//Bank Database 
 contract BankDb is DougEnabled {
     mapping (address => uint) public balances;
     
     function deposit(address addr) returns (bool res){
         if(DOUG != 0x0){
             address bank = ContractProvider(DOUG).contracts("bank");
             if(msg.sender == bank ){
                 balances[addr] += msg.value;
                 return true;
             }
         }
         //REturn if deposit cant be made
         msg.sender.send(msg.value);
         return false;
     }
     
     function withdraw(address addr, uint amount)  returns (bool res){
         if(DOUG !=0x0){
             address bank = ContractProvider(DOUG).contracts("bank");
             if(msg.sender == bank ){
                 uint oldBalance = balances[addr];
                 if(oldBalance >= amount){
                     msg.sender.send(amount);
                     balances[addr] = oldBalance - amount;
                     return true;
                 }
             }
         }
         return false;
     }
 }
 contract Bank is FundManagerEnabled {
     
     function deposit(address userAddr) returns (bool res) {
         
         if(!isFundManager()){
             return false;
         }
         address bankdb = ContractProvider(DOUG).contracts("bankdb");
         if(bankdb == 0x0 ){
             msg.sender.send(msg.value);
             return false;
             
         }
         bool success = BankDb(bankdb).deposit.value(msg.value)(userAddr);
         
         if(!success) {
             msg.sender.send(msg.value);
         }
         return success;
     }
     
     function withdraw(address userAddr, uint amount) returns (bool res){
     if(!isFundManager()){
         return false;
     }
     address bankdb = ContractProvider(DOUG).contracts("bankdb");
     
     if(bankdb == 0x0) {
         return false;
     }
     
     bool success = BankDb(bankdb).withdraw(userAddr, amount);
     
     if(success){
         userAddr.send(amount);
     }
    
     return success;
     }
 }
 
 //the fund manager
 contract FundManager is DougEnabled {
     address owner;
     
     function FundManager(){
         owner = msg.sender;
     }
     
     function deposit() returns (bool res){
         if(msg.value == 0){
             return false;
         }
         address bank = ContractProvider(DOUG).contracts("bank");
         address permsdb = ContractProvider(DOUG).contracts("permsdb");
         if(bank == 0x0 || permsdb == 0x0 || PermissionsDb(permsdb).perms(msg.sender)<1){
             msg.sender.send(msg.value);
             return false;
             
         }
         bool success = Bank(bank).deposit.value(msg.value)(msg.sender);
         
         if(!success) {
             msg.sender.send(msg.value);
         }
         return success;
     }
     
     function withdraw(uint amount) returns (bool res){
         if(amount == 0){
             return false;
         }
         address bank = ContractProvider(DOUG).contracts("bank");
         address permsdb = ContractProvider(DOUG).contracts("permsdb");
         if(bank == 0x0 || permsdb == 0x0 || PermissionsDb(permsdb).perms(msg.sender)<1){
             msg.sender.send(msg.value);
             return false;
         }
         
         bool success = Bank(bank).withdraw(msg.sender, amount);
         
         if(success){
             msg.sender.send(amount);
         }
         return success;
     }
     
     function setPermission(address addr, uint8 permLvl) returns (bool res){
         if(msg.sender != owner){
             return false;
         }
         address perms = ContractProvider(DOUG).contracts("perms");
         if(perms == 0X0){
             return false;
         }
         return Permissions(perms).setPermission(addr,permLvl);
     }
 }
 
