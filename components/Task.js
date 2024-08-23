import React, { useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Checkbox } from 'react-native-paper';
import { Swipeable } from 'react-native-gesture-handler';

const Task = (props) => {
    const swipeableRef = useRef(null);

    const renderRightActions = () => (
        <TouchableOpacity
            onPress={() => {
                swipeableRef.current?.close(); // Close the swipeable before deletion
                setTimeout(() => props.onDeleteTask(), 300); // Delay deletion for smooth animation
            }}
            style={styles.deleteButton}
        >
            <Text style={styles.deleteText}>Delete</Text>
        </TouchableOpacity>
    );

    return (
        <Swipeable
            ref={swipeableRef}
            renderRightActions={renderRightActions}
            onSwipeableWillClose={() => {
                // Optional: Additional logic when swipeable is closing
            }}
            onSwipeableOpen={() => {
                // Optional: Additional logic when swipeable is opening
            }}
            onSwipeableWillOpen={() => {
                // Optional: Additional logic when swipeable is opening
            }}
            onSwipeableClose={() => {
                // Optional: Additional logic when swipeable is closing
            }}
        >
            <TouchableOpacity onPress={props.onToggleTask}>
                <View style={styles.item}>
                    <View style={styles.itemLeft}>
                        <Checkbox
                            status={props.isCompleted ? 'checked' : 'unchecked'}
                            onPress={props.onToggleTask}
                            color="#7161EF"
                        />
                        <Text style={[styles.itemText, props.isCompleted && styles.completedText]}>
                            {props.text}
                        </Text>
                    </View>
                </View>
            </TouchableOpacity>
        </Swipeable>
    );
};

const styles = StyleSheet.create({
    item: {
        backgroundColor: '#7161EF',
        padding: 15,
        borderRadius: 10,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 20,
    },
    itemLeft: {
        flexDirection: 'row',
        alignItems: 'center',
        flexWrap: 'wrap',
    },
    itemText: {
        maxWidth: '100%',
        color: '#FFF',
        fontSize: 20,
    },
    completedText: {
        textDecorationLine: 'line-through',
        color: '#A9A9A9',
    },
    deleteButton: {
        backgroundColor: '#FF6347',
        justifyContent: 'center',
        alignItems: 'center',
        width: 80,
        height: '80%',
        borderTopRightRadius: 10,
        borderBottomRightRadius: 10,
    },
    deleteText: {
        color: '#FFF',
        fontSize: 18,
        fontWeight: 'bold',
    },
});

export default Task;
