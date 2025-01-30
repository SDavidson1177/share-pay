// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SharePay {
    struct Bill {
        address owner;
        string title;
        uint amount;
        uint remainder_index;
        uint delta;
        uint last_payment;
        address[] participants;
        address[] requests;
    }

    struct BillIndex {
        address owner;
        string title;
    }

    address private _owner;
    mapping(address => mapping(string => Bill)) private _bills;
    mapping(address => uint) private _balances;
    mapping(address => mapping(string => mapping(address => bool))) private _paused;
    mapping(address => BillIndex[]) private _bill_list;

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
        return Bill(msg.sender, "", 0, 0, 0, 0, new address[](0), new address[](0));
    }

    // Check if a bill is null
    function isBillNull(Bill memory b) public pure returns(bool) {
        return b.amount == 0;
    }

    // Create a bill
    function createBill(string memory _title, uint _amount, uint _delta) public {
        _bills[msg.sender][_title] = Bill({owner: msg.sender, title: _title, amount: _amount, remainder_index: 0, 
        delta: _delta, last_payment: 0, participants: new address[](0), requests: new address[](0)});
        _bill_list[msg.sender].push(BillIndex(msg.sender, _title));
    }

    // Get a bill
    function getBill(address _bill_owner, string memory _title) public view returns (Bill memory) {
        Bill memory b = _bills[_bill_owner][_title];
        assert(!isBillNull(b));

        return b;
    }

    // Get bills
    function getBills(address _bill_owner) public view returns (Bill[] memory) {
        if (_bill_list[_bill_owner].length == 0) {
            return new Bill[](0);
        }

        Bill[] memory bills = new Bill[](_bill_list[_bill_owner].length);
        for (uint i = 0; i < _bill_list[_bill_owner].length; i++) {
            bills[i] = _bills[_bill_list[_bill_owner][i].owner][_bill_list[_bill_owner][i].title];
        }

        return bills;
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
                // Add bill
                _bills[msg.sender][_title].participants.push(requester);
                _bill_list[requester].push(BillIndex(msg.sender, _title));

                // Update the request array
                address[] memory new_requests = new address[](b.requests.length - 1);
                uint offset = 0;
                for (uint j = 0; j < b.requests.length; j++) {
                    if (j == i) {
                        offset++;
                        continue;
                    }

                    new_requests[j-offset] = b.requests[j];
                }

                _bills[msg.sender][_title].requests = new_requests;
            }
        }
    }

    // Pause bill payments
    function pause(address _bill_owner, string memory _title) public {
        _paused[_bill_owner][_title][msg.sender] = true;
    }

    function unpause(address _bill_owner, string memory _title) public {
        _paused[_bill_owner][_title][msg.sender] = false;
    }

    function isPaused(address _bill_owner, string memory _title, address participant) public view returns(bool) {
        return _paused[_bill_owner][_title][participant];
    }

    // Removal from bill
    function leave(address _bill_owner, string memory _title) public {
        Bill memory b = getBill(_bill_owner, _title);

        uint j = 0;
        uint i = 0;
        for (; i < b.participants.length; i++) {
            if (b.participants[i] == msg.sender) {
                j = i + 1;
            } else {
                // Pause all participants. Since each participant will need
                // to pay more when a someone leaves, they should opt
                // back in by unpausing themselves.
                _paused[_bill_owner][_title][b.participants[i]] = true;
            }

            if (i < j && j < b.participants.length) {
                _bills[_bill_owner][_title].participants[i] = _bills[_bill_owner][_title].participants[j];
            }

            j++;
        }

        assert(i != j);
        _bills[_bill_owner][_title].participants.pop();
    }
    
    // Participant deposit and withdraw funds
    function deposit() public payable {
        _balances[msg.sender] += msg.value;
    }

    function balance() public view returns(uint) {
        return _balances[msg.sender];
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
        assert(b.last_payment == 0 || (b.last_payment != 0 && block.timestamp - b.last_payment >= b.delta));

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
                assert(!isPaused(b.owner, _title, b.participants[i]));
                assert(_balances[b.participants[i]] >= amount_payable + rem);

                _balances[b.participants[i]] -= amount_payable + rem;
                _balances[b.owner] += amount_payable + rem;
            } else {
                assert(b.owner.balance >= amount_payable + rem);
            }

            i = (i + 1) % (b.participants.length + 1);
        } while (i != stop);

        // Save changes to bill
        b.last_payment = block.timestamp;
        _bills[msg.sender][_title] = b;
    }
}