// SPDX-License-Identifier: MIT

pragma solidity ^ 0.8.0;

interface Ilink {
    function getPledgedInfo() external view returns(bool pledgedA_, bool pledgedB_);
    function getStatus() external view returns(string memory);
    function getLinkInfo() external view returns(string memory symbol_,address token_, address userA_,address userB_, uint256 amountA_,uint256 amountB_,uint256 percentA_,uint256 totalPlan_,uint256 lockDays_, uint256 startTime_, uint256 status_, bool isAward_);
    function getCloseInfo() external view returns(address closer_, uint256 startTime_,uint256 expiredTime_,uint256 closeTime_, bool closeReqA_, bool closeReqB_);
    function getRecevabesInfo() external view returns(uint256 receivableA_, bool isExitA_, uint256 receivableB_, bool isExitB_);
    function setUserB(address _userB) external;
    function agree() external payable;
    function reject() external;
    function close() external;
    function rejectClose() external;
    function repealCloseReq() external;
    function isExpire() external returns(bool);
    function pledge() external;
    function depledge() external;
    function wtihdrawSelf() external;
}

interface Ipledger {
    function pledge(address _user, uint256 _amount) external;
    function depledge(address _user) external;
}