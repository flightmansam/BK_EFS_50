package org.launchcode;

import com.jogamp.newt.event.WindowAdapter;
import com.jogamp.newt.event.WindowEvent;
import com.jogamp.newt.opengl.GLWindow;
import com.jogamp.opengl.GLCapabilities;
import com.jogamp.opengl.GLProfile;
import com.jogamp.opengl.util.FPSAnimator;

public class EADI implements Runnable{

    public static int width = 500;
    public static  int height = 500;

    private Thread thread_0;
    private boolean running = false;

    private static GLWindow window = null;

    public void pre_init(){
        thread_0 = new Thread(this, "EADI_Renderer");
        thread_0.start();
        running = true;
    }

    public void init(){
        GLProfile.initSingleton();
        GLProfile profile = GLProfile.get(GLProfile.GL2);
        GLCapabilities caps = new GLCapabilities(profile);
        caps.setSampleBuffers(true);
        caps.setNumSamples(10);

        window = GLWindow.create(caps);
        window.setTitle("EADI");
        window.setSize(width, height);
        window.setResizable(false);
        window.setVisible(true);
        window.addGLEventListener(new EventListener());

        FPSAnimator animator = new FPSAnimator(window, 60, true);
        animator.start();

        window.addWindowListener(new WindowAdapter() {
            @Override
            public void windowDestroyNotify(WindowEvent windowEvent) {
                running = false;
                animator.stop();
                System.exit(1);

            }
        });



    }

    public void run(){
        init();
        while(running){
            update();
            render();
        }

    }

    private void update() {

    }

    private void render() {
    }

    public static void main(String[] args) {
        new EADI().pre_init();
    }
}





