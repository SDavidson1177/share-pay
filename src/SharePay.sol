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

    // Participant deposits funds
    function deposit() public payable {
        _balances[msg.sender] += msg.value;
    }

    // Bill owner accepts payment for a bill
    function acceptPayment(string memory _title) public payable {
        Bill memory b = getBill(msg.sender, _title);
        assert(b.owner == msg.sender);

        // payable(msg.sender).transfer(10 ether);

        uint amount_payable = b.amount / (b.participants.length + 1);
        uint remainder = b.amount % (b.participants.length + 1);

        for (uint i = 0; i < b.participants.length; i++) {
            uint rem = 0;
            if (remainder > 0) {
                rem++;
                remainder--;
            }

            assert(_balances[b.participants[i]] >= amount_payable + rem);
            _balances[b.participants[i]] -= amount_payable + rem;
            payable(b.owner).transfer(amount_payable + rem);
        }

    }
}