pragma solidity >= 0.5 < 0.8;

import "./DCAUserAccount.sol";
import "./implementationsRegistry.sol";

contract DCAFactory{
    address public admin;
    implementationsRegistry private Registry;
    event AccountCreated(address indexed owner, address account);
    
    constructor(address _impl) public {
        admin = msg.sender;
        Registry = new implementationsRegistry(_impl); 
    }
    
    function registerImplementation(address _impl) public{
        require(msg.sender==admin);
        require(Registry.register(_impl));
    }
    
    function createDCA() public{
        dcaUserAccount userContract = new dcaUserAccount(address(Registry));
        require(userContract.setup(msg.sender,admin));
        emit AccountCreated(msg.sender, address(userContract));
    }
    
        
}
