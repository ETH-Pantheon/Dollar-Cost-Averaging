pragma solidity >=0.5 < 0.8;


interface RegistryInterface{   
    function getLatestVersionAddress() external view returns (address);
    function register(address _impl) external;
}



contract dcaUserAccount {
    
    address implementation;
    address registryAddress;

    constructor(address _registryAddress) public {
        registryAddress = _registryAddress;
        implementation = RegistryInterface(_registryAddress).getLatestVersionAddress();
    }
    
    function upgrade() public returns (address){
      implementation = RegistryInterface(registryAddress).getLatestVersionAddress();
    }

    fallback() payable external {
        address _impl = implementation;
        require(implementation != address(0));
    
        assembly {
          let ptr := mload(0x40)
          calldatacopy(ptr, 0, calldatasize())
          let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
          let size := returndatasize()
          returndatacopy(ptr, 0, size)
    
          switch result
          case 0 { revert(ptr, size) }
          default { return(ptr, size) }
        }
    }
    
    receive() payable external{
        
    }
}
