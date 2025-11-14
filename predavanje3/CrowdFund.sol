// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFund {
    address public owner;
    uint public goal;
    uint public deadline;
    uint public totalRaised;
    bool public goalReached;
    bool public fundsWithdrawn;
    mapping(address => uint) public contributions;
    event DonationReceived(address indexed donor, uint amount);
    event FundsWithdrawn(address indexed to, uint amount);
    event RefundIssued(address indexed to, uint amount);
    uint private _status;
    modifier nonReentrant() {
        require(_status == 0, "Reentrant call");
        _status = 1;
        _;
        _status = 0;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    modifier campaignActive() {
        require(block.timestamp < deadline, "Campaign ended");
        _;
    }
    modifier campaignEnded() {
        require(block.timestamp >= deadline, "Campaign still active");
        _;
    }
    constructor(uint _goalWei, uint _durationMinutes) {
        owner = msg.sender;
        goal = _goalWei;
        deadline = block.timestamp + (_durationMinutes * 1 minutes);
        totalRaised = 0;
        goalReached = false;
        fundsWithdrawn = false;
        _status = 0;
    }
    function donate() external payable campaignActive {
        require(msg.value > 0, "Donate non-zero amount");
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit DonationReceived(msg.sender, msg.value);
    }
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
    function getTimeLeft() public view returns (uint) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
    function _updateCampaignStatus() internal {
        if (!goalReached && block.timestamp >= deadline) {
            if (totalRaised >= goal) {
                goalReached = true;
            } else {
                goalReached = false;
            }
        }
    }
    function withdrawFunds() external onlyOwner campaignEnded nonReentrant {
        _updateCampaignStatus();
        require(goalReached, "Goal not reached");
        require(!fundsWithdrawn, "Funds already withdrawn");
        uint amount = address(this).balance;
        fundsWithdrawn = true;
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Withdraw failed");
        emit FundsWithdrawn(owner, amount);
    }
    function refund() external campaignEnded nonReentrant {
        _updateCampaignStatus();
        require(!goalReached, "Goal was reached, no refunds");
        uint contributed = contributions[msg.sender];
        require(contributed > 0, "No contribution to refund");
        contributions[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: contributed}("");
        require(success, "Refund failed");
        emit RefundIssued(msg.sender, contributed);
    }
}
