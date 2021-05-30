--- manila-12.0.1.dev15/manila/share/drivers/cephfs/driver.py.orig	2021-05-30 00:42:11.883048055 +0000
+++ manila-12.0.1.dev15/manila/share/drivers/cephfs/driver.py	2021-05-30 01:08:24.660375014 +0000
@@ -149,8 +149,12 @@
     pass
 
 
+# CWM FIX - 'mon-mgr' is in Octopus.  Octopus ceph packages not yet available in Kolla for Wallaby.
+# mon-mgr --> mgr, minus 'name=...' logic...
+#def rados_command(rados_client, prefix=None, args=None, json_obj=False,
+#                  target=('mon-mgr', )):
 def rados_command(rados_client, prefix=None, args=None, json_obj=False,
-                  target=('mon-mgr', )):
+                  target=('mgr', )):
     """Safer wrapper for ceph_argparse.json_command
 
     Raises error exception instead of relying on caller to check return
