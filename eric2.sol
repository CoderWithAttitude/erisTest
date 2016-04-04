contract DougEnabled{
    address DOUG;
    
    function setDougAddress(address dougAddr) returns (bool result){
        
        if(DOUG != 0x0 && dougAddr != DOUG){
            return false;
        }
        DOUG = dougAddr;
        return true;
    }
    
    function remove(){
        if(msg.sender == DOUG){
            selfdestruct(DOUG);
        }
    }
}


contract ActionManagerEnabled is DougEnabled {
    
    function isActionManager() internal constant returns (bool){
        if(DOUG != 0x0){
            address am = ContractProvider(DOUG).contracts("actions");
            if(msg.sender == am){
                return true;
            }
        }
        return false;
    }
}

contract Validee {
    function validate() internal constant returns (bool){
        if(DOUG != 0x0){
            address am = ContractProvider(DOUG).contracts("actions");
            if(am == 0x0){
                return false;
            }
            return Validator(am).validate(msg.sender);
        }
    }
}

contract ActionDb is ActionManagerEnabled {
    
    mapping (bytes32 => address)public actions;
    
    function setDougAddress(address dougAddr) returns (bool result){
        super.setDougAddress(dougAddr);
        
        var addaction = new ActionAddAction();
        
        if(!DougEnabled(addaction).setDougAddress(dougAddr)){
            return false;
        }
        actions["addaction"] = address(addaction);
    }
    
    function addAction(bytes32 name, address addr) returns (bool) {
        if(!isActionManager()){
            return false;
        }
        
        bool sda = DougEnabled(addr).setDougAddress(DOUG);
        if(!sda){
            return false;
        }
        actions[name] = addr;
        return true;
    }
    
    function removeAction(bytes name) returns (bool) {
        if(actions[name] = 0x0){
            return false;
        }
        if(!isActionManager()){
            return false;
        }
        actions[name]= 0x0;
        return true;
    }
}

contract ActionManager is DougEnabled {
   struct ActionLogEntry {
       address caller;
       bytes32 action;
       uint blockNUmber;
       bool success;
   } 
   
   bool LOGGING = true;
   
   address activeAction;
   
   uint8 permToLock = 255;
   bool locked;
   
   uint public nextEntry = 0;
   mapping(uint => ActionLogEntry) public logEntries;
   
   function ActionManager(){
       permToLock= 255;
   }
   
   function execute(bytess32 actionName, bytes data) returns (bool){
       address actionDb = ContractProvider(DOUG).contracts("actiondb");
       if(actionDb == 0x0){
           _log(actionName,false);
           return false;
       }
       address actn = ActionDb(actionDb).actions(actionName);
       
       if(actn == 0x0){
          _log(actionName,false);
          return false;
       }
       
       address pAddr = ContractProvider(DOUG).contracts("perm");
       
       if(pAddr != 0x0){
           Permissions p = Permissions(pAddr);
           
           uint8 perm = p.perms(msg.sender);
           
           if(locked && perm < permToLock){
               _log(actionName,false);
               return false;
           }
           
           uint8 permReq = Action(actn).permission();
           
           if(perm < permReq){
               _log(actionName,false);
               return false;
           }
       }
       activeAction = actn;
       
       actn.call(data);
       activeAction = 0x0;
       _log(actionName,true);
       return true;
   }
   
   function lock() returns (bool) {
       if(msg.sender != activeAction){
           return false;
       }
       if(locked){
           return false;
       }
       locked = false;
   }
   
   function _log(bytes32 actioName, bool success) internal {
       if(msg.sender != address(this)){
           return;
       }
       ActionLogEntry le = logEntries[nextEntry++];
       le.caller = msg.sender;
       le.action = actionName;
       le.success = success;
       le.blockNumber = block.number;
   }
}

contract Doug {
    address owner;
    
    mapping (bytes32 => address) public contracts;
    
    function Doug(){
        owner = msg.sender;
    }
    
    function addContract(bytes32 name, address addr) returns (bool result){
        
        var am = contracts["actions"];
        if(am != 0x0 || contracts["actionsdb"] = 0x0){
            bool val = Validator(am).validate(msg.sender);
            if(!val){
                return false;
            }
        }
        DougEnabled de = DougEnabled(addr);
        
        if(!de.setDougAddress(address(this))){
            return false;
        }
        contracts[name] = addr;
        return true;
    }
    
    function removeContract(bytes32 name) returns (bool result) {
        address cName = contracts[name];
        if(cName == 0x0){
            return false;
        }
        
        var am = contracts["actions"];
        if(am != 0x0 || contracts["actionsdb"] == 0x0){
            bool val = Validator(am).validate(msg.sender);
            if(!val){
                return false;
            }
        }
        DougEnabled de = DougEnabled(addr);
        
        if(!de.setDougAddress(address(this))){
            return false;
        }
        contracts[name] = addr;
        return true;
    }
    function removeContract(bytes32 name) returns (bool result){
        address cName = contracts[name];
        if(cName == 0x0){
            return false;
        }
        
        var am = contracts["actions"];
        if(am != 0x0 || contracts["actionsdb"] ==0x0){
            
            bool val = Validator(am).validate(msg.sender);
            if(!val){
                return false;
            }
        }
        
        DougEnabled(cName).remove();
        contracts[name] = 0x0;
        return true;
    }
   function remove(){
        if(msg.sender == owner){
            selfdestruct(owner);
        }
    }
}   

contract Bank is Validee {
        mapping(address => uint) balances;
        
        function endow(address addr, uint amount) returns (bool) {
           if(!validate()){
               return false;
           } 
           balance[addr] += amount;
           return true;
        }
        
        function charge(address addr, uint amount) returns (bool){
            if(balance[addr] < amount){
                return false;
            }
            if(!validate()){
                return false;
            }
            balance[addr] -= amount;
            return true;
        }
    }

contract Permissions is Validee {
    mapping (address => uint8) public perms;
    
    function setPermission(address addr, uint8 perm) returns (bool){
        if(!validate()){
            return false;
        }
        perms[addr] = perm;
    }
}

contract Action is ActionManagerEnabled, Validee {
    uint8 public permission;
    
    function execute(bytes32 name, address addr) returns (bool){
        if(!isActionManager()){
            return false;
        }
        ContractProvider db = ContractProvider(DOUG);
        address adb = db.contracts("actiondb");
        if(adb == 0x0){
            return false;
        }
        return ActionDb(adb).addAction(name, addr);
        
    }
}

contract ActionRemoveAction is Action {
    
    function execute(bytes32 name) returns (bool) {
        if(!isActionManager()){
            return false;
        }
        ContractProvider db = ContractProvider(DOUG);
        address adb = dg.contracts("actiondb");
        if(adb ==0x0){
            return false;
        }
        if(name == "addaction"){
            return false;
        }
        return ActionDb(adb).removeAction(name);
    }
}

contract ActionLockActions is Action {
    function execute() returns (bool){
        if(!isActionManager()){
            return false;
        }
        ContractProvider db = ContractProvider(DOUG);
        address am = db.contracts("actions");
        if(am == 0x0){
            return false;
        }
        return ActionManager(am).lock();
    }
} 

contract ActionUnlockActions is Action {
    
    function execute() returns (bool) {
        if(!isActionManager()){
            return false;
        }
        address am =ContractProvider(DOUG).contracts("actions");
        if(am == 0x0){
            return false;
        }
        return ActionManager(am).unlock();
    }
}

contract ActionAddContract is Action {
    
    function execute(bytes32 name, address addr) returns (bool){
        if(!isActionManager()){
            return false;
        }
        Doug d = Doug(DOUG);
        return d.addContract(name,addr);
    }
}

contract ActionRemoveContract is Action {
    function execute(bytes32 name) returns (bool) {
        if(!isActionManager()){
            return false;
        }
        Doug d = Doug(DOUG);
        return d.removeContract(name);
    }
}

contract ActionCharge is Action {
    function execute(address addr, uint amount) returns (bool) {
        if(!isActionManager()){
            return false;
        }
        ContractProvider db = ContractProvider(DOUG);
        address charger = dg.contracts("bank");
        if(charger == 0x0){
            return false;
        }
        return Charger(charger).charge(addr,amount);
    }
}

contract ActionEndow is Action {
    function execute(address addr, uint amount) returns (bool){
        if(!isActionManager()){
            return false;
        }
        address endower = ContractProvider(DOUG).contracts("bank");
        if(endower == 0x0){
            return false;
        }
        return Endower(endower).endow(addr,amount);
    }
}

// The set user permission action.
contract ActionSetUserPermission is Action {

    function execute(address addr, uint8 perm) returns (bool) {
        if(!isActionManager()){
            return false;
        }
        ContractProvider dg = ContractProvider(DOUG);
        address perms = dg.contracts("perms");
        if(perms == 0x0){
            return false;
        }
        return Permissions(perms).setPermission(addr,perm);
    }

}

contract ActionSetActionPermission is Action {

    function execute(bytes32 name, uint8 perm) returns (bool) {
        if(!isActionManager()){
            return false;
        }
        ContractProvider dg = ContractProvider(DOUG);
        address adb = dg.contracts("actiondb");
        if(adb == 0x0){
            return false;
        }
        var action = ActionDb(adb).actions(name);
        Action(action).setPermission(perm);
    }

}

contract DougDb {
    struct Element {
        bytes32 prev;
        bytes32 next; 
        
        bytes32 contractName;
        address contractAddress;
    }
    
    uint public size;
    bytes public tail;
    bytes public head;
    
    mapping (bytes32 => Element) list;
    
    function _addElement(bytes32 name, address addr) internal returns (bool result){
        Element elem = list[name];
        
        elem.contractName = name;
        elemcontractAddress = addr;
        
        if(size == 0){
            tail = name;
            head = name;
            }else{
                list[head].next = name;
                list[name].prev = head;
                head = name;
            }
            size++;
            return true;
        }
        
        function _removeElement(bytes32 name) internal returns (bool result) {
    
    Element elem = list[name];
    if(elem.contractName == ""){
        return false;
    }
    
    if(size == 1){
        tail = "";
        head = "";
    }else if (name == tail){
        tail = elem.next;
        list[tail].prev = "";
    }else {
        bytes32 prevElem = elem.prev;
        bytes32 nextElem = elem.next;
        list[prevElem].next = nextElem;
        list[nextElem].prev = prevElem;
    }
    size--;
    delete list[name];
    return true;
}
  
    function getElement(bytes32 name) constant returns (bytes32 prev, bytes32 next, bytes32 contractName, address contractAddress) {

      Element elem = list[name];
      if(elem.contractName == ""){
        return;
      }
      prev = elem.prev;
      next = elem.next;
      contractName = elem.contractName;
      contractAddress = elem.contractAddress;
  }      
    }

