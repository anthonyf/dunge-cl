(defpackage dunge/tests/item
  (:use :cl
	:dunge/item
	:rove))
(in-package :dunge/tests/item)

;;; Non-stackable item tests

(deftest test-non-stackable-defaults
  (testing "non-stackable item is a plain item, not stackable"
    (let ((sword (make-item "Sword (d8)")))
      (ok (string= (item-name sword) "Sword (d8)"))
      (ok (typep sword 'item))
      (ok (not (typep sword 'stackable))))))

(deftest test-non-stackable-ignores-quantity
  (testing "non-stackable item ignores quantity argument"
    (let ((sword (make-item "Sword (d8)" :quantity 5)))
      (ok (not (typep sword 'stackable))))))

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
    (let ((sword (make-item "Sword (d8)")))
      (ok (string= (item-display-name sword) "Sword (d8)")))))

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
    (let ((sword (make-item "Sword (d8)")))
      (ok (null (item-actions sword))))))

(deftest test-stackable-item-actions-returns-nil
  (testing "stackable item has no actions"
    (let ((rations (make-item "Rations" :stackable t :stack-limit 10 :quantity 3)))
      (ok (null (item-actions rations))))))
