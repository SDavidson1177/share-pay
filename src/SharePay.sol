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
    mapping(address => mapping(string => Bill)) private _bills;
    // Bill[] private _bills;


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
        _bills[msg.sender][_title] = Bill({owner: msg.sender, title: _title, amount: _amount, participants: new address[](0), requests: new address[](0)});
    }

    // Get a bill
    function getBill(address _bill_owner, string memory _title) public view returns (Bill memory) {
        Bill memory b = _bills[_bill_owner][_title];
        assert(!isBillNull(b));

        return b;
    }

    /* PARTICIPANT INTERACTIONS */

    // Request to join a bill
    function requestToJoin(address _bill_owner, string memory _title) public {
        // check that bill exists
        getBill(_bill_owner, _title);

        _bills[_bill_owner][_title].requests.push(msg.sender);
    }

    function acceptRequest(string memory _title, address requester) public {
        // check that bill exists
        Bill memory b = getBill(msg.sender, _title);

        for (uint i = 0; i < b.requests.length; i++) {
            if (b.requests[i] == requester) {
                _bills[msg.sender][_title].participants.push(requester);
            }
        }
    }

}