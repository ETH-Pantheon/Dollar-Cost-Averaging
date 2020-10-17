pragma solidity >= 0.5 < 0.8;

contract implementationsRegistry{
    
    address private factory;
    uint256 private latestVersion;
    mapping(uint256=>address) private implementations;
    event newImplementation(address impl_Addr, uint256 version);
    
    
    constructor(address _impl) public {
        factory = msg.sender;
        register(_impl);
    }
    
    modifier OnlyFactory(){
        require(msg.sender==factory);
        _;
    }
    
    function getLatestVersionAddress() public view returns (address){
        return implementations[latestVersion];
    }
    
    
    function register(address _impl) public OnlyFactory returns(bool) {
        latestVersion = latestVersion + 1;
        implementations[latestVersion] = _impl;
        emit newImplementation(_impl,latestVersion);
        return true;
    }
}
