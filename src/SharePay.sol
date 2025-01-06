// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SharePay {
    struct Bill {
        address owner;
        string title;
        uint amount;
        address[] participants;
    }

    address private _owner;
    Bill[] private _bills;

    constructor() {
        _owner = msg.sender;
    }

    function areStringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    // Create a null bill
    function nullBill() public view returns (Bill memory) {
        return Bill(msg.sender, "", 0, new address[](0));
    }

    // Check if a bill is null
    function isBillNull(Bill memory b) public pure returns(bool) {
        return b.amount == 0;
    }

    // Create a bill
    function createBill(string memory _title, uint _amount) public {
        _bills.push(Bill({owner: msg.sender, title: _title, amount: _amount, participants: new address[](0)}));
    }

    // Get a bill
    function getBill(string memory _title) public view returns (Bill memory) {
        for (uint i = 0; i < _bills.length; i++) {
            if (areStringsEqual(_bills[i].title, _title)) {
                return _bills[i];
            }
        }

        return nullBill();
    }

}