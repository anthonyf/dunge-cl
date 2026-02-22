(defpackage #:dunge/tests/data-store
  (:use #:cl #:rove)
  (:import-from #:dunge #:lookup #:*data-store*))
(in-package #:dunge/tests/data-store)

;;; lookup tests

(deftest test-lookup-nil-store
    (testing "looking up a key in a nil store returns nil"
             (let ((*data-store* nil))
               (ok (null (lookup "foo"))))))

(deftest test-lookup-missing-key
    (testing "looking up a missing key returns nil"
             (let ((*data-store* (make-hash-table :test 'equal)))
               (ok (null (lookup "nonexistent"))))))

(deftest test-lookup-single-key
    (testing "looking up a single key returns the stored value"
             (let ((*data-store* (make-hash-table :test 'equal)))
               (setf (gethash "foo" *data-store*) 42)
               (ok (= (lookup "foo") 42)))))

(deftest test-lookup-nested-keys
    (testing "looking up nested keys traverses hash tables"
             (let* ((*data-store* (make-hash-table :test 'equal))
                    (inner (make-hash-table :test 'equal)))
               (setf (gethash "room" inner) 'my-room)
               (setf (gethash "rooms" *data-store*) inner)
               (ok (eq (lookup "rooms" "room") 'my-room)))))

(deftest test-lookup-missing-intermediate-key
    (testing "looking up a nested path with missing intermediate returns nil"
             (let ((*data-store* (make-hash-table :test 'equal)))
               (ok (null (lookup "rooms" "nonexistent"))))))

(deftest test-lookup-non-hash-intermediate
    (testing "looking up through a non-hash-table intermediate returns nil"
             (let ((*data-store* (make-hash-table :test 'equal)))
               (setf (gethash "foo" *data-store*) 42)
               (ok (null (lookup "foo" "bar"))))))

;;; setf lookup tests

(deftest test-set-single-key
    (testing "setting a single key stores the value"
             (let ((*data-store* nil))
               (setf (lookup "foo") 42)
               (ok (= (lookup "foo") 42)))))

(deftest test-set-creates-store
    (testing "setting a key on a nil store creates the hash table"
             (let ((*data-store* nil))
               (setf (lookup "foo") 'bar)
               (ok (hash-table-p *data-store*)))))

(deftest test-set-nested-keys
    (testing "setting nested keys creates intermediate hash tables"
             (let ((*data-store* nil))
               (setf (lookup "rooms" "my-room") 'room-goes-here)
               (ok (eq (lookup "rooms" "my-room") 'room-goes-here)))))

(deftest test-set-deeply-nested
    (testing "setting deeply nested keys creates all intermediates"
             (let ((*data-store* nil))
               (setf (lookup "a" "b" "c") 'deep)
               (ok (eq (lookup "a" "b" "c") 'deep)))))

(deftest test-set-preserves-siblings
    (testing "setting a key does not disturb sibling keys"
             (let ((*data-store* nil))
               (setf (lookup "rooms" "room-a") 'a)
               (setf (lookup "rooms" "room-b") 'b)
               (ok (eq (lookup "rooms" "room-a") 'a))
               (ok (eq (lookup "rooms" "room-b") 'b)))))

(deftest test-set-overwrite
    (testing "setting an existing key overwrites the value"
             (let ((*data-store* nil))
               (setf (lookup "foo") 'old)
               (setf (lookup "foo") 'new)
               (ok (eq (lookup "foo") 'new)))))

(deftest test-set-nil-removes-key
    (testing "setting a key to nil removes it"
             (let ((*data-store* nil))
               (setf (lookup "foo") 42)
               (setf (lookup "foo") nil)
               (ok (null (lookup "foo"))))))

(deftest test-set-nil-nested-removes-key
    (testing "setting a nested key to nil removes it"
             (let ((*data-store* nil))
               (setf (lookup "rooms" "my-room") 'room)
               (setf (lookup "rooms" "my-room") nil)
               (ok (null (lookup "rooms" "my-room"))))))

(deftest test-set-nil-preserves-siblings
    (testing "removing a key does not disturb sibling keys"
             (let ((*data-store* nil))
               (setf (lookup "rooms" "room-a") 'a)
               (setf (lookup "rooms" "room-b") 'b)
               (setf (lookup "rooms" "room-a") nil)
               (ok (null (lookup "rooms" "room-a")))
               (ok (eq (lookup "rooms" "room-b") 'b)))))
