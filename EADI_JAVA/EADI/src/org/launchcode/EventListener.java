package org.launchcode;

import com.jogamp.opengl.GL2;
import com.jogamp.opengl.GLAutoDrawable;
import com.jogamp.opengl.GLEventListener;
import properties.Color;

public class EventListener implements GLEventListener {

    public float v_roll = 0.001f;
    public float roll = 0.0f;
    public boolean split = true;
    public Color sky = new Color(0x2A, 0x6C, 0xA5);
    public Color ground = new Color(0x78, 0x5C, 0x3D);

    public void display(GLAutoDrawable glAutoDrawable) {
        GL2 gl = glAutoDrawable.getGL().getGL2();

        gl.glClear(GL2.GL_COLOR_BUFFER_BIT | GL2.GL_DEPTH_BUFFER_BIT);

        gl.glTranslatef(EADI.width/2, EADI.height/2, 0.0f);
        gl.glRotatef(roll,0.0f, 0.0f, 1.0f);
        gl.glTranslatef(-EADI.width/2, -EADI.height/2, 0.0f);

        gl.glColor3f(ground.r, ground.g, ground.b); //gnd
        gl.glBegin(GL2.GL_QUADS);
        gl.glVertex2f(-EADI.width/2, (EADI.height/2)+1);
        gl.glVertex2f(-EADI.width/2, -EADI.height/2);
        gl.glVertex2f(3*EADI.width/2, -EADI.height/2);
        gl.glVertex2f(3*EADI.width/2, (EADI.height/2)+1);

        gl.glTranslatef(EADI.width / 2, EADI.height / 2, 0.0f);
        gl.glRotatef(roll, 0.0f, 0.0f, 1.0f);
        gl.glTranslatef(-EADI.width / 2, -EADI.height / 2, 0.0f);

        gl.glColor3f(sky.r, sky.g, sky.b);
        gl.glBegin(GL2.GL_QUADS);
        gl.glVertex2f(-EADI.width / 2, 3 * EADI.height / 2);
        gl.glVertex2f(-EADI.width / 2, EADI.height / 2);
        gl.glVertex2f(3 * EADI.width / 2, EADI.height / 2);
        gl.glVertex2f(3 * EADI.width / 2, 3 * EADI.height / 2);

        gl.glFlush();
        gl.glEnd();

        System.out.println(roll);

        if (roll > 1 | roll < -1){
            v_roll *= -1;
        }
        roll += v_roll;
    }

    public void dispose(GLAutoDrawable glAutoDrawable) {

    }

    public void init(GLAutoDrawable glAutoDrawable) {
        GL2 gl = glAutoDrawable.getGL().getGL2();
        gl.glClearColor(0,0,0,1);
    }

    public void reshape(GLAutoDrawable glAutoDrawable, int x, int y, int width, int height) {
        GL2 gl = glAutoDrawable.getGL().getGL2();

        gl.glMatrixMode(GL2.GL_PROJECTION);
        gl.glLoadIdentity();
        gl.glOrtho(0, EADI.width, 0, EADI.height, -1, 1);

    }
}
