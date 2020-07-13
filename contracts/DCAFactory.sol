pragma solidity ^0.6;

import 'https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/CloneFactory.sol';

abstract contract DCA{
    function setup(address owner_) virtual public returns(bool);
}

contract DCAFactory is CloneFactory{
    
    address DCATemplate = 0x276Eb817A919414EE1b67DAf3A6C29a20f61384F;
    mapping(address => address) private users;
    constructor() public {
        
    }
    
    
    function createDCA() public{
        address userContract = createClone(DCATemplate);
        require(DCA(userContract).setup(msg.sender));
        users[msg.sender] = userContract;
    }
    
    
    function getUsersAccount() public view returns(address){
        return users[msg.sender];
    }
    
}
