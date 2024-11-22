// run from base folder:
// certoraRun test/14-priority/certora.conf
methods {
    // `envfree` definitions to call functions without explicit `env`
    function getCollateralAtPriority(uint8) external returns(uint8)   envfree;
    function containsCollateral(uint8)      external returns(bool)    envfree;
    function numCollateral()                external returns(uint256) envfree;
}

// verify priority queue order is correctly maintained:
// - `addCollateral` adds new id to end of the queue
// - `removeCollateral` maintains existing order minus removed id
rule priority_order_correct() {
    // require no initial collateral to prevent HAVOC corrupting
    // EnumerableSet _positions -> _values references
    require numCollateral() == 0;

    // setup initial state with collateral_id order: 1,2,3 which ensures
    // EnumerableSet _positions -> _values references are correct
    env e1;
    addCollateral(e1, 1);
    addCollateral(e1, 2);
    addCollateral(e1, 3);

    // sanity check initial state
    require numCollateral() == 3  && containsCollateral(1) &&
            containsCollateral(2) && containsCollateral(3);

    // sanity check initial order; this also verifies that
    // addCollateral worked as expected
    require getCollateralAtPriority(0) == 1 &&
            getCollateralAtPriority(1) == 2 &&
            getCollateralAtPriority(2) == 3;

    // successfully remove first id 1
    removeCollateral(e1, 1);

    // verify it was removed and other ids still exist
    require numCollateral() == 2  && !containsCollateral(1) &&
            containsCollateral(2) && containsCollateral(3);

    // assert existing order 2,3 preserved minus the removed first id 1
    assert getCollateralAtPriority(0) == 2 &&
           getCollateralAtPriority(1) == 3;
}