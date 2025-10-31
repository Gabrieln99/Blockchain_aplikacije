// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract StudentRecord{
    struct Student{
        string name;
        uint grade;
    }

    mapping ( uint => Student ) public students;
    uint public count; 

    function addStudent(string memory _name, uint _grade) public{
        students[count] = Student (_name, _grade);
        count++;
    }

    function getStudent(uint _id) public view returns (string memory){
        Student memory s = students[_id];
        return s.name;
    }

        /* ZADATAK ZA BODOVE:
Dodaj funkciju "updateGrade" koja mijenja ocjenu studenta.
Koristi require da provjeriš da student postoji.
Testiraj funkciju u Remixu.
    function updateGrade
*/


    function updateGrade (uint _id, uint _newGrade) public{
        require(_id < count, "Student ne postoji");

        students[_id].grade = _newGrade;
    }


}