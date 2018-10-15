/*
 *run_planner_comparison_glass_scenario.cpp
 *
 *  Created on: Jan 20, 2016
 *      Author: Felix Burget
 */


#include <ros/ros.h>
#include <birrt_star_algorithm/birrt_star.h>
#include <rrt_star_algorithm/rrt_star.h>
#include <planning_world_builder/planning_world_builder.h>


using namespace std;

int main(int argc, char** argv)
{
    //Init Node
    ros::init(argc, argv, "run_planner_comparison_glass_node");

    //Node Handle
    ros::NodeHandle nh;

    //Read package path from parameter server
    //string terminal_configs_path;
    //nh.param("terminal_configs_path", terminal_configs_path, std::string("/home/burgetf/catkin_ws/src/robot_motion_planning/planning_scenarios/Start_Goal_Configurations"));

    //Get package path of "planning_scenarios"
    string terminal_configs_path;
    terminal_configs_path = ros::package::getPath("planning_scenarios");

    //Set planning group
    //string planning_group = "omnirob_lbr_sdh";


    // -------------------- Get Planning Setup ----------------------------

    //Set default values
    string PLANNING_GROUP = "omnirob_lbr_sdh";
    int NUM_PLANNING_RUNS = 1;
    double FLAG_ITERATIONS_OR_TIME = 0;
    double MAX_ITERATIONS_TIME = 200;


    //Set planning group
    if(argc > 1) {
      stringstream s(argv[1]);
      s >> PLANNING_GROUP;
    }
    //Set maximum iterations for planner
    if(argc > 2) {
      stringstream s(argv[2]);
      s >> NUM_PLANNING_RUNS;
    }
    //Set flag indicating whether maximum iterations or time for planner is used
    if(argc > 3) {
      stringstream s(argv[3]);
      s >> FLAG_ITERATIONS_OR_TIME;
    }
    //Set maximum iterations or time for planner
    if(argc > 4) {
      stringstream s(argv[4]);
      s >> MAX_ITERATIONS_TIME;
    }



    // -------------------- Planning World Setup ----------------------------
    //Load Planning World
    planning_world::PlanningWorldBuilder world_builder("robot_description", PLANNING_GROUP);
    //Enter Environment Borders
    vector<double> env_size_x(2);
    env_size_x[0] = -10.0;
    env_size_x[1] = 10.0;
    vector<double> env_size_y(2);
    env_size_y[0] = -10.0;
    env_size_y[1] = 10.0;
    double env_size_z = 2.0;
    world_builder.insertEnvironmentBorders(env_size_x,env_size_y,env_size_z);


    //Insert Glass Delivery Scenario
   double tunnel_height = 1.4;
   double tunnel_width = 1.5; //Note : omnirob has width of 0.67m
   double ceiling_height = 1.2;
   world_builder.insertGlassDeliveryWorld(tunnel_width, tunnel_height, ceiling_height);

    //Path to the file containing the start and goal config for the scenario
    char* file_path_start_goal_config;
    string folder_path = terminal_configs_path + "/Start_Goal_Configurations/" + PLANNING_GROUP + "_glass_start_goal_config.txt";
    file_path_start_goal_config = new char[folder_path.size() + 1];
    copy(folder_path.begin(), folder_path.end(), file_path_start_goal_config);
    file_path_start_goal_config[folder_path.size()] = '\0'; // don't forget the terminating 0
    //cout<<file_path_start_goal_config<<endl;


    // -------------------- Attached Objects ----------------------------
    //Dimension of attached_object
    vector<double> glass_dim(3);
    glass_dim[0] = 0.08;   //x-width dim
    glass_dim[1] = 0.08;   //y-length dim
    glass_dim[2] = 0.12;   //z-height dim

    //Start Position of attached_object
    vector<double> obj_pos_start(3);
    obj_pos_start[0] = 9.0;   //x pos
    obj_pos_start[1] = -4.0;  //y pos
    obj_pos_start[2] = 0.9;   //z pos
    moveit_msgs::AttachedCollisionObject glass = world_builder.insertManipulableGlass("glass", obj_pos_start, glass_dim);

    //Goal Position of attached_object
    vector<double> obj_pos_goal(3);
    obj_pos_goal[0] = -8.0;   //x pos
    obj_pos_goal[1] = 3.0;  //y pos
    obj_pos_goal[2] = 0.9;   //z pos
    moveit_msgs::AttachedCollisionObject glass_goal = world_builder.insertManipulableGlass("glass_goal", obj_pos_goal, glass_dim);


    // -------------------- Planner Setup ----------------------------

    //Bidirectional Planner
    birrt_star_motion_planning::BiRRTstarPlanner bi_planner(PLANNING_GROUP);
    //Unidirectional Planner
    rrt_star_motion_planning::RRTstarPlanner uni_planner(PLANNING_GROUP);

    //Set planning scene
    bi_planner.setPlanningSceneInfo(world_builder);
    uni_planner.setPlanningSceneInfo(world_builder);


    //To determine whether bidirectional or unidirectional search is performed
    enum Search { bi, uni, nn};
    Search search_direction = bi;

    // -------------------- Set Planner to run ----------------------------
    vector<string> planner_to_run;
    //planner_to_run.push_back("uni_rrt");                //Standard RRT
    planner_to_run.push_back("uni_rrt_star");           //Standard RRT*
    //planner_to_run.push_back("uni_informed_rrt");       //Informed RRT
    planner_to_run.push_back("uni_informed_rrt_star");  //Informed RRT*

    planner_to_run.push_back("bi_rrt_connect");         //Standard Bidirectional RRT
    planner_to_run.push_back("bi_rrt_star");            //Bidirectional RRT*
    planner_to_run.push_back("bi_informed_rrt");        //Bidirectional Informed RRT
    planner_to_run.push_back("bi_informed_rrt_star");   //Bidirectional Informed RRT*



    //Run each planner NUM_PLANNING_RUNS times
    for (int i = 0 ; i < planner_to_run.size(); i++)
    {
        if(planner_to_run[i] == "bi_informed_rrt_star")
        {
            bi_planner.activateInformedSampling();
            bi_planner.activateTreeOptimization();
            search_direction = bi;
        }
        else if (planner_to_run[i] == "uni_informed_rrt_star")
        {
            uni_planner.activateInformedSampling();
            uni_planner.activateTreeOptimization();
            search_direction = uni;
        }
        else if (planner_to_run[i] == "bi_rrt_star")
        {
            bi_planner.deactivateInformedSampling();
            bi_planner.activateTreeOptimization();
            search_direction = bi;
        }
        else if (planner_to_run[i] == "uni_rrt_star")
        {
            uni_planner.deactivateInformedSampling();
            uni_planner.activateTreeOptimization();
            search_direction = uni;
        }
        else if (planner_to_run[i] == "bi_informed_rrt")
        {
            bi_planner.activateInformedSampling();
            bi_planner.deactivateTreeOptimization();
            search_direction = bi;
        }
        else if (planner_to_run[i] == "uni_informed_rrt")
        {
            uni_planner.activateInformedSampling();
            uni_planner.deactivateTreeOptimization();
            search_direction = uni;
        }
        else if (planner_to_run[i] == "bi_rrt_connect")
        {
            bi_planner.deactivateInformedSampling();
            bi_planner.deactivateTreeOptimization();
            search_direction = bi;
        }
        else if (planner_to_run[i] == "uni_rrt")
        {
            uni_planner.deactivateInformedSampling();
            uni_planner.deactivateTreeOptimization();
            search_direction = uni;
        }
        else
        {
            search_direction = nn; //nn = not known
            ROS_ERROR("Unknown Planner Type!!!");
            //Shutdown node
            ros::shutdown();
        }




        // -------------------- Planning Settings ----------------------------


        //Global Frame (top view)
        //       ^ Y
        //       |
        //       | f
        //       |Z
        //   f   X-----> X
        //
        //         f



        //Set constraint parameters / permitted axes for displacement (x,y,z,roll,pitch,yaw) relative to start ee pose during planning
        //  1 -> constraint
        //  0 -> unconstraint
        vector<int> constraint_vector(6);
        constraint_vector[0] = 0.0; //X translation
        constraint_vector[1] = 0.0; //Y translation
        constraint_vector[2] = 0.0; //Z translation
        constraint_vector[3] = 1.0; //X rotation
        constraint_vector[4] = 0.0; //Y rotation
        constraint_vector[5] = 1.0; //Z rotation
        //Permitted displacement for ee coordinates w.r.t task frame
        vector<pair<double,double> > permitted_coordinate_dev(6);
        permitted_coordinate_dev[0].first = 0.0;    //negative X deviation [m]
        permitted_coordinate_dev[0].second = 0.0;   //positive X deviation
        permitted_coordinate_dev[1].first = 0.0;    //negative Y deviation
        permitted_coordinate_dev[1].second = 0.0;   //positive Y deviation
        permitted_coordinate_dev[2].first = 0.0;    //negative Z deviation
        permitted_coordinate_dev[2].second = 0.0;   //positive Z deviation
        permitted_coordinate_dev[3].first = -0.174;    //negative Xrot deviation [rad]
        permitted_coordinate_dev[3].second = 0.174;   //positive Xrot deviation
        permitted_coordinate_dev[4].first = 0.0;    //negative Yrot deviation
        permitted_coordinate_dev[4].second = 0.0;   //positive Yrot deviation
        permitted_coordinate_dev[5].first = -0.174;    //negative Zrot deviation
        permitted_coordinate_dev[5].second = 0.174;   //positive Zrot deviation
        //Activate the constraint
        // -> Syntax: planner.setParameterizedTaskFrame(constraint_vector, permitted_coordinate_dev, bool task_pos_global, bool task_orient_global);
        // bool task_pos_global -> indicates whether task frame position is expressed w.r.t near node ee pos or always w.r.t start frame ee pos
        // bool task_orient_global -> indicates whether task frame orientation is expressed w.r.t near node ee orientation or always w.r.t start frame ee orientation



        //Set edge cost variable weights (to apply motion preferences)
        vector<double> edge_cost_weights(10);
        edge_cost_weights[0] = 1.0; //base_x
        edge_cost_weights[1] = 1.0; //base_y
        edge_cost_weights[2] = 1.0; //base_theta
        edge_cost_weights[3] = 1.0; //manipulator joint 1
        edge_cost_weights[4] = 1.0; //manipulator joint 2
        edge_cost_weights[5] = 1.0; //manipulator joint 3
        edge_cost_weights[6] = 1.0; //manipulator joint 4
        edge_cost_weights[7] = 1.0; //manipulator joint 5
        edge_cost_weights[8] = 1.0; //manipulator joint 6
        edge_cost_weights[9] = 1.0; //manipulator joint 7



        // Init planner with start/goal pose + Set end-effector constraints + Set Edge Cost Weights
        if (search_direction == uni)
        {

            //Initialize planner (with start and ee goal pose)
            //uni_planner.init_planner(start_ee_pose, constraint_vec_start_pose, ee_goal_pose, constraint_vec_goal_pose, 1);
            uni_planner.init_planner(file_path_start_goal_config, 1);

            //Activate the constraint
            uni_planner.setTaskFrameConstraints(constraint_vector,permitted_coordinate_dev,true,true);

            //Set edge costs
            uni_planner.setEdgeCostWeights(edge_cost_weights);

            //Remove the cart at the goal position (it has been only used for getting a valid/coll.-free goal configuration))
            world_builder.deleteCollisionObject(glass_goal);

            //Attach the cart to the endeffector being in the start pose before planning (in order to consider the cart in collision checking)
            uni_planner.attachObject(glass);
        }
        else if (search_direction == bi)
        {
            //Initialize planner (with start and ee goal pose)
            //bi_planner.init_planner(start_ee_pose, constraint_vec_start_pose, ee_goal_pose, constraint_vec_goal_pose, 1);
            bi_planner.init_planner(file_path_start_goal_config, 1);

            //Activate the constraint
            bi_planner.setTaskFrameConstraints(constraint_vector,permitted_coordinate_dev,true,true);

            //Set edge costs
            bi_planner.setEdgeCostWeights(edge_cost_weights);

            //Remove the cart at the goal position (it has been only used for getting a valid/coll.-free goal configuration))
            world_builder.deleteCollisionObject(glass_goal);

            //Attach the cart to the endeffector being in the start pose before planning (in order to consider the cart in collision checking)
            bi_planner.attachObject(glass);
        }
        else
            ROS_ERROR("Unknown Planner Type!!!");



        // -------------------- Motion Planning Execution ----------------------------
        //Planning result
        bool success = false;

        //Execute NUM_PLANNING_RUNS planning runs
        for (int run = 0 ; run < NUM_PLANNING_RUNS ; run++)
        {
            if (search_direction == uni)
            {
                //Run planner
                // Params: search_space, max_iter, visu_on_off, sleep_between_iters, current_run_number
                success = uni_planner.run_planner(1, FLAG_ITERATIONS_OR_TIME, MAX_ITERATIONS_TIME, 0, 0.0, run);

                //Reset planner data
                uni_planner.reset_planner_only();
            }
            else if (search_direction == bi)
            {
                //Run planner
                // Params: search_space, max_iter, visu_on_off, sleep_between_iters, current_run_number
                success = bi_planner.run_planner(1, FLAG_ITERATIONS_OR_TIME, MAX_ITERATIONS_TIME, 0, 0.0, run);

                //Reset planner data
                bi_planner.reset_planner_only();
            }
            else
                ROS_ERROR("Unknown Planner Type!!!");

            //End of "run"-th planning run
            cout<<"Planner run "<< run <<" finished with: "<<(success == true ? "success":"failure")<<endl;

        }//End of planner runs

    } //End of looping through planners


    //Shutdown node
    ros::shutdown();

    return 0;
}



