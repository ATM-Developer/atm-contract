// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ;

interface IERC20 {
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
}

interface IPledgeContract {
    function queryNodeIndex(address _nodeAddr) external view returns(uint256);
}

interface Isenator{
    function getExecuter() external view returns (address);
    function isSenator(address user) external view returns (bool);
}

interface IEfficacyContract {
    function verfiyParams(address[2] calldata addrs,uint256[2] calldata uints,bytes32 code, bytes32 digest) external view returns(bool);
}

interface IIncentive {
    function withdrawToken(address[2] calldata addrs,uint256[2] calldata uints,bytes32 code,uint8[] calldata vs,bytes32[] calldata rssMetadata) external;
}

abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

contract Ownable is Initializable{
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init_unchained() internal initializer {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract  IncentiveV3  is Initializable,Ownable,IIncentive {
    IPledgeContract public pledgeContract;
    bytes32 public DOMAIN_SEPARATOR;
    bool public pause;
    mapping(address => uint256) public nonce;
    mapping(address => uint256) public withdrawSums;
    mapping(address => mapping(uint256 => uint256)) public withdrawAmounts;
    IEfficacyContract public efficacyContract;
    address public exector;
    uint256 public threshold;
    mapping(uint256 => uint256) public withdrawLimit;
    uint256 public signNum;
    address public senator;
    address public exectorTwo;
    uint256 public lastExecuteTime;
    address public lastExector;
    event WithdrawToken(address indexed _userAddr, uint256 _nonce, uint256 _amount);
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public approval1;
    mapping(address => bool) public approval2;
    event AddedToBlacklist(address indexed _address);
    event DeleteToBlacklist(address indexed _address);
    event ApprovalReceived(address indexed _address, address indexed _approver);

    struct Data {
        address userAddr;
        address contractAddr;
        uint256 amount;
        uint256 expiration;
    }

    struct Sig {
        /* v parameter */
        uint8 v;
        /* r parameter */
        bytes32 r;
        /* s parameter */
        bytes32 s;
    }

    modifier onlyGuard() {
        require(!pause, "IncentiveContracts: The system is suspended");
        _;
    }

    function init(address _pledgeContract) external initializer{
        __Ownable_init_unchained();
        __Incentive_init_unchained(_pledgeContract);
    }
    
    function __Incentive_init_unchained(address _pledgeContract) internal initializer{
        require(_pledgeContract != address(0), "_pledgeContract address cannot be 0");
        pledgeContract = IPledgeContract(_pledgeContract);
        uint chainId;
        assembly {
            chainId := chainId
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(uint256 chainId,address verifyingContract)'),
                chainId,
                address(this)
            )
        );
    }

    receive() payable external{

    }

    function  updatePause(bool _sta) external onlyOwner{
        pause = _sta;
    }

    function  updateSenator(address _senator) external onlyOwner{
        senator = _senator;
    }

    function  updateThreshold(uint256 _threshold) external onlyOwner{
        threshold = _threshold;
    }

    function  updateSignNum(uint256 _signNum) external onlyOwner{
        require(_signNum > 18, "IncentiveContracts: parameter error");
        signNum = _signNum;
    }

    function  updateExector(uint256 _index, address _exector) external onlyOwner{
        if(_index ==1){
            exector = _exector;
        }else {
            exectorTwo = _exector;
        }
        
    }

    function close() external{
        require(exector == msg.sender || exectorTwo == msg.sender, "IncentiveContracts: not exector");
        if (lastExector == address(0) || lastExector == msg.sender) {
            lastExector = msg.sender;
            lastExecuteTime = block.timestamp;
        } else if (block.timestamp - lastExecuteTime <= 2 days) {
            pause = true;
        } else {
            lastExector = msg.sender;
            lastExecuteTime = block.timestamp;
        }
    }

    function approveBlacklisting(address[] calldata addrs) external {
        require(exector == msg.sender || exectorTwo == msg.sender, "IncentiveContracts: not exector");
        address addr;
        for (uint i=0; i<addrs.length; i++){
            addr = addrs[i];
            if (msg.sender == exector) {
                approval1[addr] = true;
            } else if (msg.sender == exectorTwo) {
                approval2[addr] = true;
            }
            emit ApprovalReceived(addr, msg.sender);

            if (approval1[addr] && approval2[addr]) {
                isBlacklisted[addr] = true;
                emit AddedToBlacklist(addr);
            }
        }
    }

    function cancelBlacklisting(address[] calldata addrs) external onlyOwner{
        for (uint i=0; i<addrs.length; i++){
            isBlacklisted[addrs[i]] = false;
            emit DeleteToBlacklist(addrs[i]);
        }
    }

    function  updateEfficacyContract(address _addr) external onlyOwner{
        efficacyContract = IEfficacyContract(_addr);
    }

    /**
    * @notice A method to the user withdraw revenue.
    * The extracted proceeds are signed by at least 11 PAGERANK servers, in order to withdraw successfully
    */
    function withdrawToken(
        address[2] calldata addrs,
        uint256[2] calldata uints,
        bytes32 code,
        uint8[] calldata vs,
        bytes32[] calldata rssMetadata
    )
        override
        external
        onlyGuard
    {
        require(addrs[0] == msg.sender, "IncentiveContracts: Signing users are not the same as trading users");
        require(!isBlacklisted[msg.sender], "IncentiveContracts: invalid address");
        require( block.timestamp<= uints[1], "IncentiveContracts: The transaction exceeded the time limit");
        uint256 len = vs.length;
        uint256 counter;
        uint256 _nonce = nonce[addrs[0]]++;
        require(len*2 == rssMetadata.length, "IncentiveContracts: Signature parameter length mismatch");
        require(verfylimit(uints[0]),"Extraction limit exceeded");
        uint256[] memory arr = new uint256[](len);
        bytes32 digest = getDigest(Data( addrs[0], addrs[1], uints[0], uints[1]), _nonce);
        require(efficacyContract.verfiyParams(addrs, uints, code, digest), "IncentiveContracts: code error");
        for (uint256 i = 0; i < len; i++) {
            (bool result, address signAddr) = verifySign(
                digest,
                Sig(vs[i], rssMetadata[i*2], rssMetadata[i*2+1])
            );
            arr[i] = uint256(uint160(signAddr));
            if (result){
                counter++;
            }
        }
        uint256 _signNum = (signNum != 0) ? signNum : 18;
        require(
            counter >= _signNum,
            "The number of signed accounts did not reach the minimum threshold"
        );
        require(areElementsUnique(arr), "IncentiveContracts: Signature parameter not unique");
        withdrawSums[addrs[0]] +=  uints[0];
        withdrawAmounts[addrs[0]][_nonce] =  uints[0];
        IERC20  token = IERC20(addrs[1]);
        require(
            token.transfer(addrs[0],uints[0]),
            "Token transfer failed"
        );
        emit WithdrawToken(addrs[0], _nonce, uints[0]);
    }
    
    function verifySign(bytes32 _digest,Sig memory _sig) internal view returns (bool, address)  {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 hash = keccak256(abi.encodePacked(prefix, _digest));
        address _accessAccount = ecrecover(hash, _sig.v, _sig.r, _sig.s);
        bool result = Isenator(senator).isSenator(_accessAccount);
        address executer = Isenator(senator).getExecuter();
        if(!result && executer == _accessAccount)result=true;
        return (result, _accessAccount);
    }

    function verfylimit(uint256 amount) internal returns (bool) {
        uint256 day = block.timestamp/86400;
        withdrawLimit[day] += amount;
        return threshold > withdrawLimit[day];
    }

    function areElementsUnique(uint256[] memory arr) internal pure returns (bool) {
        for(uint i = 0; i < arr.length - 1; i++) {
            for(uint j = i + 1; j < arr.length; j++) {
                if (arr[i] == arr[j]) {
                    return false; 
                }
            }
        }
        return true; 
    }

    function getDigest(Data memory _data, uint256 _nonce) internal view returns(bytes32 digest){
        digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(_data.userAddr, _data.contractAddr,  _data.amount, _data.expiration, _nonce))
            )
        );
    }
}

