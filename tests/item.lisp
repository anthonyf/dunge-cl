(defpackage dunge/tests/item
  (:use :cl
	:dunge/item
	:rove))
(in-package :dunge/tests/item)

;;; Non-stackable item tests

(deftest test-non-stackable-defaults
  (testing "non-stackable item is a plain item, not stackable"
    (let ((shield (make-item "Shield")))
      (ok (string= (item-name shield) "Shield"))
      (ok (typep shield 'item))
      (ok (not (typep shield 'stackable))))))

(deftest test-non-stackable-ignores-quantity
  (testing "non-stackable item ignores quantity argument"
    (let ((shield (make-item "Shield" :quantity 5)))
      (ok (not (typep shield 'stackable))))))

;;; Stackable item tests

(deftest test-stackable-item
  (testing "stackable item respects quantity and stack-limit"
    (let ((rations (make-item "Rations" :stackable t :stack-limit 10 :quantity 3)))
      (ok (typep rations 'stackable))
      (ok (typep rations 'item))
      (ok (= (item-quantity rations) 3))
      (ok (= (item-stack-limit rations) 10)))))

(deftest test-stackable-clamps-quantity
  (testing "stackable item clamps quantity to stack-limit"
    (let ((torches (make-item "Torch" :stackable t :stack-limit 5 :quantity 20)))
      (ok (= (item-quantity torches) 5)))))

;;; Display name tests

(deftest test-display-name-non-stackable
  (testing "non-stackable item shows just the name"
    (let ((shield (make-item "Shield")))
      (ok (string= (item-display-name shield) "Shield")))))

(deftest test-display-name-stackable-qty-gt-1
  (testing "stackable item with qty > 1 shows Name xN"
    (let ((rations (make-item "Rations" :stackable t :stack-limit 10 :quantity 3)))
      (ok (string= (item-display-name rations) "Rations x3")))))

(deftest test-display-name-stackable-qty-1
  (testing "stackable item with qty = 1 shows just the name"
    (let ((torch (make-item "Torch" :stackable t :stack-limit 5 :quantity 1)))
      (ok (string= (item-display-name torch) "Torch")))))

;;; item-actions tests

(deftest test-item-actions-returns-nil
  (testing "base item has no actions"
    (let ((shield (make-item "Shield")))
      (ok (null (item-actions shield))))))

(deftest test-stackable-item-actions-returns-nil
  (testing "stackable item has no actions"
    (let ((rations (make-item "Rations" :stackable t :stack-limit 10 :quantity 3)))
      (ok (null (item-actions rations))))))

;;; Weapon tests

(deftest test-weapon-constructor
  (testing "weapon constructor creates weapon-item with correct slots"
    (let ((sword (weapon "Sword" :damage-die 8)))
      (ok (typep sword 'weapon-item))
      (ok (typep sword 'weapon))
      (ok (typep sword 'item))
      (ok (string= (item-name sword) "Sword"))
      (ok (= (item-damage-die sword) 8)))))

(deftest test-weapon-display-name
  (testing "weapon display name includes damage die"
    (let ((sword (weapon "Sword" :damage-die 8)))
      (ok (string= (item-display-name sword) "Sword (d8)")))
    (let ((dagger (weapon "Dagger" :damage-die 6)))
      (ok (string= (item-display-name dagger) "Dagger (d6)")))))

(deftest test-weapon-usable-p
  (testing "weapons are usable in combat"
    (let ((sword (weapon "Sword" :damage-die 8)))
      (ok (usable-p sword)))))

(deftest test-weapon-use-label
  (testing "weapon use label shows attack text"
    (let ((sword (weapon "Sword" :damage-die 8)))
      (ok (string= (item-use-label sword) "Attack with Sword (d8)")))))

(deftest test-plain-item-not-usable
  (testing "plain items are not usable in combat"
    (let ((shield (make-item "Shield")))
      (ok (not (usable-p shield))))))

;;; Healing herb tests

(deftest test-healing-herb-constructor
  (testing "healing-herb constructor creates correct type"
    (let ((herbs (healing-herb :quantity 3)))
      (ok (typep herbs 'healing-herb))
      (ok (typep herbs 'consumable))
      (ok (typep herbs 'stackable))
      (ok (typep herbs 'item))
      (ok (string= (item-name herbs) "Healing Herbs"))
      (ok (= (item-quantity herbs) 3)))))

(deftest test-healing-herb-display-name
  (testing "healing-herb display name shows quantity when > 1"
    (let ((herbs (healing-herb :quantity 3)))
      (ok (string= (item-display-name herbs) "Healing Herbs x3")))
    (let ((herbs (healing-herb :quantity 1)))
      (ok (string= (item-display-name herbs) "Healing Herbs")))))

(deftest test-healing-herb-use-label
  (testing "healing-herb use label shows consume text"
    (let ((herbs (healing-herb :quantity 1)))
      (ok (string= (item-use-label herbs) "Use Healing Herbs")))))

;;; Consume-item tests

(deftest test-consume-item-decrements-stackable
  (testing "consume-item decrements stackable quantity"
    (let* ((herbs (healing-herb :quantity 3))
	   (inventory (list herbs (make-item "Shield")))
	   (new-inv (consume-item herbs inventory)))
      (ok (= (item-quantity herbs) 2))
      (ok (= (length new-inv) 2)))))

(deftest test-consume-item-removes-at-zero
  (testing "consume-item removes item when quantity reaches 0"
    (let* ((herbs (healing-herb :quantity 1))
	   (shield (make-item "Shield"))
	   (inventory (list herbs shield))
	   (new-inv (consume-item herbs inventory)))
      (ok (= (item-quantity herbs) 0))
      (ok (= (length new-inv) 1))
      (ok (eq (first new-inv) shield)))))

(deftest test-consume-item-removes-non-stackable
  (testing "consume-item removes non-stackable item"
    (let* ((shield (make-item "Shield"))
	   (torch (make-item "Torch"))
	   (inventory (list shield torch))
	   (new-inv (consume-item shield inventory)))
      (ok (= (length new-inv) 1))
      (ok (eq (first new-inv) torch)))))
