pragma solidity ^0.6;

import 'https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/CloneFactory.sol';

abstract contract interfaceDCA{
    function setup(address owner_) virtual public returns(bool);
}

contract DCAFactory is CloneFactory{
    
    address payable DCATemplate;
    
    event AccountCreated(address indexed owner, address account);
    
    constructor(address DCATemplate_) public {
        DCATemplate = DCATemplate_;
    }
    
    
    function createDCA() public{
        address userContract = createClone(DCATemplate);
        require(interfaceDCA(userContract).setup(msg.sender));
        AccountCreated(msg.sender, userContract);
    }
        
}
