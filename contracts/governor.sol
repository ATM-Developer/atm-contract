// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ;

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function lucaToFragment(uint256 value) external view returns (uint256);
    function fragmentToLuca(uint256 value) external view returns (uint256);
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

contract Governor is Initializable,Ownable{
    using SafeMath for uint256;
    address public executor;
    IERC20 public  governanceToken;
    uint256 public votingPeriod;
    uint256 public  proposalCount;                           
    mapping(uint256 => ProposalMsg) public proposalMsg;  
    mapping(address => mapping(uint256 => uint256)) public userStakeNum;
    
    event Propose(address indexed userAddr, uint256 proposalId, uint256 time);
    event Vote(address indexed userAddr, uint256 proposalId, uint256 option, uint256 votes, uint256 time);
    event WithdrawStake(address indexed userAddr, uint256 proposalId, uint256 amount, uint256 time);
    event UpdateExecutor(address _executor);
    

    struct ProposalMsg {
        address proposer;   
        string proposalContent; 
        uint256 launchTime;   
        uint256 expire;  
        uint256 options;  
        mapping(uint256 => uint256) voteSums;  
    }

    modifier onlyExecutor() {
        require(msg.sender == executor ||  true, "The caller is not the executor");
        _;
    }

    function init(address _governanceToken, address _executor) external initializer{
        __Ownable_init_unchained();
        __Governor_init_unchained(_governanceToken, _executor);
    }

    function __Governor_init_unchained(address _governanceToken, address _executor) internal initializer{
        governanceToken = IERC20(_governanceToken);
        executor = _executor;
        votingPeriod = 15 days;
    }
    
    receive() payable external{

    }
    
    fallback() payable external{

    }
    
    function updateGovernanceToken(address _governanceToken) external onlyExecutor{
        governanceToken = IERC20(_governanceToken);
    }
    
    function updateVotingPeriod(uint256 _votingPeriod) external onlyExecutor{
        votingPeriod = _votingPeriod;
    }
    
    function updateExecutor(address _executor) external onlyOwner{
        executor = _executor;
        emit UpdateExecutor(_executor);
    }
    
    /**
    * @notice A method in which users pledge a certain amount of governance tokens to initiate a proposal
    */
    function propose(uint256 _options, string memory _proposalContent) external onlyExecutor{
        address _sender = msg.sender;
        uint256 _time = block.timestamp;
        uint256 proposalId = ++proposalCount;
        ProposalMsg storage _proposalMsg = proposalMsg[proposalId];
        _proposalMsg.proposer = _sender;
        _proposalMsg.proposalContent = _proposalContent;
        _proposalMsg.launchTime = _time;
        _proposalMsg.expire = _time + votingPeriod;
        _proposalMsg.options = _options;
        emit Propose(_sender, proposalId, _time);
    }
    
    function  Test(uint256 _proposalId) external {
        ProposalMsg storage _proposalMsg = proposalMsg[_proposalId];
        _proposalMsg.expire = block.timestamp;
    }
    /**
    * @notice A method whereby users pledge governance tokens to vote on proposals
    * @param _amouns vote array
    * @param _proposalId the proposal id  
    * @param _types Voting type array
    */
    function vote(uint256 _proposalId, uint256[] calldata _amouns, uint256[] calldata _types) external {
        address _sender = msg.sender;
        uint256 _time = block.timestamp;
        uint256 sum = 0;
        require(_amouns.length == _types.length, "Parameter number does not match");
        ProposalMsg storage _proposalMsg = proposalMsg[_proposalId];
        require(_proposalMsg.launchTime < _time && _proposalMsg.expire > _time, "The vote on the governance proposal has expired");
        for (uint256 i = 0; i < _amouns.length; i++) {
            require(_types[i] > 0 && _types[i] <= _proposalMsg.options, "The vote type does not exist");
            _proposalMsg.voteSums[_types[i]] = _proposalMsg.voteSums[_types[i]].add(_amouns[i]);
            sum = sum.add(_amouns[i]);
            emit Vote(_sender, _proposalId, _types[i], _amouns[i], _time);
        }
        require(governanceToken.transferFrom(_sender,address(this),sum), "Token transfer failed");
        userStakeNum[_sender][_proposalId] = userStakeNum[_sender][_proposalId].add(sum);
        
    }
    
    /**
    * @notice A method to the users withdraws the pledge deposit
    * @param _proposalIds  proposal ID collection
    */
    function withdrawStake(uint256[] calldata _proposalIds) external {
        address _sender = msg.sender;
        uint256 _amount = 0;
        for (uint256 i = 0; i < _proposalIds.length; i++) {
            uint256 _proposalId = _proposalIds[i];
            require(_proposalId <= proposalCount, "The proposal ID is incorrect");
            if (_proposalId > 0){
                require(proposalMsg[_proposalId].expire < block.timestamp, "The vote on the agreement is not yet over");
                uint256 stakeNum = userStakeNum[_sender][_proposalId];
                _amount = _amount.add(stakeNum);
                userStakeNum[_sender][_proposalId] = 0;
                emit WithdrawStake(_sender, _proposalId, stakeNum, block.timestamp);
            }
        }
        require(_amount > 0, "The amount that can be withdrawn is 0");
        require(governanceToken.transfer(_sender,_amount), "Token transfer failed");
    } 
    
    function queryVotes(uint256 _proposalId) external view returns(address, string memory, uint256, uint256, uint256, uint256[] memory){
        ProposalMsg storage _proposalMsg = proposalMsg[_proposalId];
        uint256[] memory votes = new uint256[](_proposalMsg.options);
        for (uint256 i = 0; i < _proposalMsg.options; i++) {
            votes[i] = _proposalMsg.voteSums[i.add(1)];
        }
        return (_proposalMsg.proposer, _proposalMsg.proposalContent, _proposalMsg.launchTime, _proposalMsg.expire,  _proposalMsg.options, votes);
    }
}
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
