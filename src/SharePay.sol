// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SharePay {
    struct Bill {
        address owner;
        string title;
        uint amount;
        address[] participants;
        address[] requests;
    }

    address private _owner;
    Bill[] private _bills;


    constructor() {
        _owner = msg.sender;
    }

    function areStringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /* BILL MANIPULATIONS */

    // Create a null bill
    function nullBill() public view returns (Bill memory) {
        return Bill(msg.sender, "", 0, new address[](0), new address[](0));
    }

    // Check if a bill is null
    function isBillNull(Bill memory b) public pure returns(bool) {
        return b.amount == 0;
    }

    // Create a bill
    function createBill(string memory _title, uint _amount) public {
        _bills.push(Bill({owner: msg.sender, title: _title, amount: _amount, participants: new address[](0), requests: new address[](0)}));
    }

    // Get a bill
    function getBill(string memory _title) public view returns (Bill memory, uint) {
        for (uint i = 0; i < _bills.length; i++) {
            if (areStringsEqual(_bills[i].title, _title)) {
                return (_bills[i], i);
            }
        }

        return (nullBill(), 0);
    }

    /* PARTICIPANT INTERACTIONS */

    // Request to join a bill
    function requestToJoin(string memory _title) public {
        (Bill memory req_bill, uint index) = getBill(_title);
        require(!isBillNull(req_bill));

        _bills[index].requests.push(msg.sender);
    }

    function acceptRequest(string memory _title, address requester) public {
        (Bill memory req_bill, uint index) = getBill(_title);
        require(!isBillNull(req_bill));
        require(req_bill.owner == msg.sender);

        for (uint i = 0; i < req_bill.requests.length; i++) {
            if (req_bill.requests[i] == requester) {
                _bills[index].participants.push(requester);
            }
        }
    }

}