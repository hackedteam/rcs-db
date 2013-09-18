*******************************************************
Using the LEADTOOLS Network Virtual Printer Server Demo
*******************************************************

The LEADTOOLS Network Virtual Printer Server Demo is designed to receive print jobs and then
save them to disk files.  In addition, this demo receives custom data from the client machine.
The additional data can be any user specific data.  In this example, the additional data are
the “File Save Name” and the desired “Save Format”.

The LEADTOOLS Virtual Printer can be installed on the client machine in the following ways:
-- Using normal Windows printer installation (point and print).
-- Using the Microsoft Internet Printing Protocol ( IPP ) Printer web page.
-- Using the LEADTOOLS Virtual Printer Client Installer Demo, which is destributed as part of
   the LEADTOOLS Virtual Printer Client Setup.

NOTES:
* Installing the printer without using the Client Installer Demo will not allow for additional
  data to be sent with the printed job.
* If you install the printer using either of the first two methods listed above, you still
  must use Client Installer Demo if you want to take advantage of the Server-Client 
  communication mechanism (to send custom additional data).
* For additional information on using the diffrent installation methods, please refer to the
  helpfile "<LEADTOOLS-Installation-Path>\Help\How To.chm".


The behavior of the LEADTOOLS Virtual Printer Server Demo depends on the manner in which the
printer driver was installed and from where you are printing:
-- If installed the printer driver using the Printer Client Installer Demo and you are
   printing a job from the client machine:
   The Server Demo will receive the custom data from the client, along with the printed job.
   The Server Demo will save the job using the settings that you selected in the Client Demo 
   on the client machine.
-- If installed the printer driver WITHOUT using the Printer Client Installer Demo and you are
   printing a job from the client machine, or if you are printing a job on the Server (local)
   machine:
   No additional data will be sent with the printed job and the Server Demo will save the
   received prin job with default settings (“PDF" with file name “Job ID”).