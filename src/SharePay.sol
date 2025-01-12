// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SharePay {
    struct Bill {
        address owner;
        string title;
        uint amount;
        uint remainder_index;
        address[] participants;
        address[] requests;
    }

    address private _owner;
    mapping(address => mapping(string => Bill)) private _bills;
    mapping(address => uint) private _balances;

    constructor() {
        _owner = msg.sender;
    }

    receive() external payable {}

    modifier billExists(address _bill_owner, string memory _title) {
        Bill memory b = _bills[_bill_owner][_title];
        assert(!isBillNull(b));

        _;
    }

    function areStringsEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /* Bill Manipulations */

    // Create a null bill
    function nullBill() public view returns (Bill memory) {
        return Bill(msg.sender, "", 0, 0, new address[](0), new address[](0));
    }

    // Check if a bill is null
    function isBillNull(Bill memory b) public pure returns(bool) {
        return b.amount == 0;
    }

    // Create a bill
    function createBill(string memory _title, uint _amount) public {
        _bills[msg.sender][_title] = Bill({owner: msg.sender, title: _title, amount: _amount, remainder_index: 0, 
        participants: new address[](0), requests: new address[](0)});
    }

    // Get a bill
    function getBill(address _bill_owner, string memory _title) public view returns (Bill memory) {
        Bill memory b = _bills[_bill_owner][_title];
        assert(!isBillNull(b));

        return b;
    }

    /* Participant Interactions */

    // Request to join a bill
    function requestToJoin(address _bill_owner, string memory _title) public billExists(_bill_owner, _title) {
        _bills[_bill_owner][_title].requests.push(msg.sender);
    }

    function acceptRequest(string memory _title, address requester) public {
        // Get the bill
        Bill memory b = getBill(msg.sender, _title);

        for (uint i = 0; i < b.requests.length; i++) {
            if (b.requests[i] == requester) {
                _bills[msg.sender][_title].participants.push(requester);
            }
        }
    }

    // Participant deposit and withdraw funds
    function deposit() public payable {
        _balances[msg.sender] += msg.value;
    }

    function withdraw(uint amount) public payable {
        assert(_balances[msg.sender] >= amount && address(this).balance >= amount);
        _balances[msg.sender] -= amount;

        payable(msg.sender).transfer(amount);
    }

    // Bill owner accepts payment for a bill
    function acceptPayment(string memory _title) public payable {
        Bill memory b = getBill(msg.sender, _title);
        assert(b.owner == msg.sender);
        assert(b.participants.length > 0);

        uint amount_payable = b.amount / (b.participants.length + 1);
        uint remainder = b.amount % (b.participants.length + 1);

        uint i = b.remainder_index;
        uint stop;
        if (i >= b.participants.length + 1) {
            i = 0;
        }
        stop = i;

        do {
            uint rem = 0;
            if (remainder > 0) {
                rem = 1;
                remainder--;
            } else if (remainder == 0) {
                b.remainder_index = i;
            }

            // Only send money if we are not accounting for the owner's share
            if (i != b.participants.length) {
                assert(_balances[b.participants[i]] >= amount_payable + rem);
                _balances[b.participants[i]] -= amount_payable + rem;
                payable(b.owner).transfer(amount_payable + rem);
            }

            i = (i + 1) % (b.participants.length + 1);
        } while (i != stop);

        // Save changes to bill
        _bills[msg.sender][_title] = b;
    }
}