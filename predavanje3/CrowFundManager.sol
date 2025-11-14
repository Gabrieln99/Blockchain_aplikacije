// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFundManager {
    address public owner;
    uint public campaignCount;
    struct Campaign {
        string title;
        address creator;
        uint goal;
        uint deadline;
        uint totalRaised;
        bool goalReached;
        bool fundsWithdrawn;
    }
    mapping(uint => Campaign) public campaigns;
    mapping(uint => mapping(address => uint)) public contributions;
    event CampaignCreated(uint indexed campaignId, string title, address indexed creator, uint goal, uint deadline);
    event DonationReceived(uint indexed campaignId, address indexed donor, uint amount);
    event FundsWithdrawn(uint indexed campaignId, address indexed to, uint amount);
    event RefundIssued(uint indexed campaignId, address indexed to, uint amount);
    uint private _status;
    modifier nonReentrant() {
        require(_status == 0, "Reentrant call");
        _status = 1;
        _;
        _status = 0;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner");
        _;
    }
    modifier onlyCreator(uint _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Only campaign creator");
        _;
    }
    modifier campaignExists(uint _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist");
        _;
    }
    constructor() {
        owner = msg.sender;
        campaignCount = 0;
        _status = 0;
    }
    function createCampaign(string memory _title, uint _goalWei, uint _durationMinutes) public {
        require(_goalWei > 0, "Goal must be > 0");
        require(_durationMinutes > 0, "Duration must be > 0");
        Campaign storage c = campaigns[campaignCount];
        c.title = _title;
        c.creator = msg.sender;
        c.goal = _goalWei;
        c.deadline = block.timestamp + (_durationMinutes * 1 minutes);
        c.totalRaised = 0;
        c.goalReached = false;
        c.fundsWithdrawn = false;
        emit CampaignCreated(campaignCount, _title, msg.sender, _goalWei, c.deadline);
        campaignCount++;
    }
    function donateTo(uint _campaignId) public payable campaignExists(_campaignId) {
        require(msg.value > 0, "Must send some ETH");
        Campaign storage c = campaigns[_campaignId];
        require(block.timestamp < c.deadline, "Campaign ended");
        contributions[_campaignId][msg.sender] += msg.value;
        c.totalRaised += msg.value;
        emit DonationReceived(_campaignId, msg.sender, msg.value);
    }
    function getBalance(uint _campaignId) public view campaignExists(_campaignId) returns (uint) {
        return address(this).balance;
    }
    function getTimeLeft(uint _campaignId) public view campaignExists(_campaignId) returns (uint) {
        Campaign storage c = campaigns[_campaignId];
        if (block.timestamp >= c.deadline) return 0;
        return c.deadline - block.timestamp;
    }
    function _updateCampaignStatus(uint _campaignId) internal {
        Campaign storage c = campaigns[_campaignId];
        if (!c.goalReached && block.timestamp >= c.deadline) {
            if (c.totalRaised >= c.goal) {
                c.goalReached = true;
            } else {
                c.goalReached = false;
            }
        }
    }
    function withdrawFunds(uint _campaignId) public campaignExists(_campaignId) onlyCreator(_campaignId) nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(block.timestamp >= c.deadline, "Campaign not ended yet");
        _updateCampaignStatus(_campaignId);
        require(c.goalReached, "Goal not reached");
        require(!c.fundsWithdrawn, "Already withdrawn");
        uint amount = c.totalRaised;
        c.fundsWithdrawn = true;
        c.totalRaised = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdraw failed");
        emit FundsWithdrawn(_campaignId, msg.sender, amount);
    }
    function refund(uint _campaignId) public campaignExists(_campaignId) nonReentrant {
        Campaign storage c = campaigns[_campaignId];
        require(block.timestamp >= c.deadline, "Campaign not ended yet");
        _updateCampaignStatus(_campaignId);
        require(!c.goalReached, "Campaign succeeded, no refunds");
        uint contributed = contributions[_campaignId][msg.sender];
        require(contributed > 0, "No contribution for refund");
        contributions[_campaignId][msg.sender] = 0;
        c.totalRaised -= contributed;
        (bool success, ) = payable(msg.sender).call{value: contributed}("");
        require(success, "Refund failed");
        emit RefundIssued(_campaignId, msg.sender, contributed);
    }
    function getContribution(uint _campaignId, address _user) public view campaignExists(_campaignId) returns (uint) {
        return contributions[_campaignId][_user];
    }
}
